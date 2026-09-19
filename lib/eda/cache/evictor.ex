defmodule EDA.Cache.Evictor do
  @moduledoc """
  Periodic LRW (Least Recently Written) evictor for caches with `max_size`.

  Shadow ETS tables track write timestamps only for caches that have a configured
  `max_size`. Caches without `max_size` incur zero overhead.

  Every `@interval` ms, the evictor checks each evictable cache and removes
  the oldest entries when the main table exceeds its limit.

  ## Example

      config :eda,
        cache: [
          users: [max_size: 100_000]
        ]
  """

  use GenServer

  @interval 5_000

  # Maps main table atom -> {timestamps_table, order_table, max_size}
  # Stored in GenServer state and also in persistent_term for O(1) lookup from cache modules.

  @doc """
  Records a write in the shadow tables. Called by cache modules on create/upsert.
  No-op if the cache has no `max_size` configured. Direct ETS ops, non-blocking.
  """
  @spec touch(atom(), term()) :: :ok
  def touch(table, key) do
    case :persistent_term.get({:eda_evictor, table}, nil) do
      nil ->
        :ok

      {ts_table, ord_table, _max} ->
        now = System.monotonic_time()

        case :ets.lookup(ts_table, key) do
          [{_, old_time}] -> :ets.delete(ord_table, {old_time, key})
          [] -> :ok
        end

        :ets.insert(ts_table, {key, now})
        :ets.insert(ord_table, {{now, key}, nil})
        :ok
    end
  end

  @doc """
  Removes a key from the shadow tables. Called by cache modules on delete.
  No-op if the cache has no `max_size` configured.
  """
  @spec remove(atom(), term()) :: :ok
  def remove(table, key) do
    case :persistent_term.get({:eda_evictor, table}, nil) do
      nil ->
        :ok

      {ts_table, ord_table, _max} ->
        case :ets.lookup(ts_table, key) do
          [{_, old_time}] ->
            :ets.delete(ts_table, key)
            :ets.delete(ord_table, {old_time, key})

          [] ->
            :ok
        end

        :ok
    end
  end

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    tables = setup_shadow_tables()
    schedule_eviction()
    {:ok, %{tables: tables}}
  end

  @impl true
  def handle_info(:evict, state) do
    for {main_table, {ts_table, ord_table, max_size}} <- state.tables do
      evict_if_needed(main_table, ts_table, ord_table, max_size)
    end

    schedule_eviction()
    {:noreply, state}
  end

  defp schedule_eviction do
    Process.send_after(self(), :evict, @interval)
  end

  defp setup_shadow_tables do
    config = Application.get_env(:eda, :cache, [])

    table_mapping = %{
      guilds: :eda_guilds,
      users: :eda_users,
      channels: :eda_channels,
      members: :eda_members,
      roles: :eda_roles,
      voice_states: :eda_voice_states,
      presences: :eda_presences
    }

    tables =
      for {config_key, main_table} <- table_mapping,
          opts = Keyword.get(config, config_key, []),
          max_size = Keyword.get(opts, :max_size),
          max_size != nil,
          into: %{} do
        ts_name = :"#{main_table}_evictor_ts"
        ord_name = :"#{main_table}_evictor_ord"

        :ets.new(ts_name, [:set, :public, :named_table, write_concurrency: true])
        :ets.new(ord_name, [:ordered_set, :public, :named_table, write_concurrency: true])

        :persistent_term.put({:eda_evictor, main_table}, {ts_name, ord_name, max_size})

        {main_table, {ts_name, ord_name, max_size}}
      end

    tables
  end

  @doc false
  @spec evict_table(atom(), atom(), atom(), non_neg_integer()) :: :ok
  def evict_table(main_table, ts_table, ord_table, max_size) do
    evict_if_needed(main_table, ts_table, ord_table, max_size)
    :ok
  end

  defp evict_if_needed(main_table, ts_table, ord_table, max_size) do
    current_size = adapter().count(main_table)

    if current_size > max_size do
      to_evict = current_size - max_size
      evicted = do_evict(main_table, ts_table, ord_table, to_evict, 0)

      if evicted > 0 do
        cache_name = table_to_cache_name(main_table)
        :telemetry.execute([:eda, :cache, :evict], %{count: evicted}, %{cache: cache_name})
      end
    end
  end

  defp do_evict(_main_table, _ts_table, _ord_table, 0, evicted), do: evicted

  defp do_evict(main_table, ts_table, ord_table, remaining, evicted) do
    case :ets.first(ord_table) do
      :"$end_of_table" ->
        evicted

      {_time, key} = ord_key ->
        :ets.delete(ord_table, ord_key)
        :ets.delete(ts_table, key)

        case adapter().get(main_table, key) do
          nil ->
            # Orphaned shadow entry, don't count as eviction
            do_evict(main_table, ts_table, ord_table, remaining, evicted)

          _entry ->
            delete_from_main(main_table, key)
            do_evict(main_table, ts_table, ord_table, remaining - 1, evicted + 1)
        end
    end
  end

  defp delete_from_main(main_table, key) do
    adapter().delete(main_table, key)

    # Clean up index tables for Channel and Role
    case main_table do
      :eda_channels ->
        {_guild_id, channel_id} = key
        adapter().delete(:eda_channels_index, channel_id)

      :eda_roles ->
        {_guild_id, role_id} = key
        adapter().delete(:eda_roles_index, role_id)

      _ ->
        :ok
    end
  end

  defp table_to_cache_name(:eda_guilds), do: :guilds
  defp table_to_cache_name(:eda_users), do: :users
  defp table_to_cache_name(:eda_channels), do: :channels
  defp table_to_cache_name(:eda_members), do: :members
  defp table_to_cache_name(:eda_roles), do: :roles
  defp table_to_cache_name(:eda_voice_states), do: :voice_states
  defp table_to_cache_name(:eda_presences), do: :presences
  defp table_to_cache_name(other), do: other

  # The eviction bookkeeping (timestamps and the LRW ordering index) stays in local ETS
  # on purpose: it is the evictor's own structure, not cached entities, and each node
  # bounds the memory it actually holds. Only operations on the cache itself go through
  # the adapter, so eviction works with any backend.
  defp adapter, do: EDA.Cache.Adapter.current()
end
