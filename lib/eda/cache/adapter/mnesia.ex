defmodule EDA.Cache.Adapter.Mnesia do
  @moduledoc """
  An `EDA.Cache.Adapter` backed by Mnesia, for caches shared across a cluster.

      config :eda, cache_adapter: EDA.Cache.Adapter.Mnesia

  Mnesia ships with OTP, so this needs no extra dependency — but it does need to be on
  your application's code path.

  > #### Add `:mnesia` to your own application {: .error}
  >
  > EDA does **not** list `:mnesia` in its `:extra_applications`, because that would start
  > Mnesia for every user of the library including those who never touch this adapter. Your
  > bot must declare it itself, or this adapter raises `:mnesia.start/0 is undefined` at
  > startup:
  >
  >     # your mix.exs
  >     def application do
  >       [extra_applications: [:logger, :mnesia], mod: {MyBot.Application, []}]
  >     end

  The adapter starts Mnesia on demand and creates one table per cache the first time it
  initialises.

  > #### Configure it before EDA starts {: .warning}
  >
  > Mnesia backs a `ram_copies` table with an ETS table of the same name, so it cannot
  > claim a name the ETS adapter already took. Set `:cache_adapter` in config, not at
  > runtime: swapping adapters in a live VM fails with
  > `{:system_limit, _, {~c"Failed to create ets table", :badarg}}`.

  ## What this buys you

  A bot running several nodes gets one view of the cache: a `GUILD_CREATE` handled on
  one shard's node is visible to every other node, and a node restarting rejoins a
  populated cache instead of a cold one. With the ETS adapter each node caches only
  what its own shards saw.

  ## Configuration

      config :eda,
        cache_adapter: EDA.Cache.Adapter.Mnesia,
        cache_mnesia: [
          copies: :ram_copies,   # or :disc_copies, :disc_only_copies
          nodes: [node()],       # nodes to place a copy on
          wait_timeout: 5_000    # ms to wait for tables at startup
        ]

  `:ram_copies` is the default and is usually right: the cache is reconstructible from
  Discord, so paying for disk writes on every `PRESENCE_UPDATE` buys little.
  `:disc_copies` additionally requires a schema on disk — call
  `:mnesia.create_schema([node()])` once before starting, or Mnesia keeps everything in
  RAM regardless.

  ## Dirty by design

  Every operation uses Mnesia's dirty API. That is deliberate: a Discord cache is a
  replica of state Discord owns, it is read on the event hot path, and a stale or lost
  entry costs one REST call rather than corrupting anything. Transactions would add
  coordination latency to every `PRESENCE_UPDATE` in exchange for a guarantee the data
  does not need.

  If two nodes write the same key concurrently, last-write-wins. That is the same
  outcome the gateway itself produces when two shards see the same entity.

  > #### Admission policy and eviction still apply {: .tip}
  >
  > They live above the adapter, so they work here unchanged. Note that eviction is
  > per-node: each node bounds the memory it holds, but the bookkeeping is local, so a
  > cluster may hold more entries in total than `max_size` suggests.
  """

  @behaviour EDA.Cache.Adapter

  # Mnesia ships with OTP but is not in this library's :extra_applications on purpose:
  # listing it there would start Mnesia for every EDA user, including the ones who never
  # touch this adapter. It is always available at runtime, so the compile-time warning is
  # noise.
  @compile {:no_warn_undefined, :mnesia}

  require Logger

  @impl true
  def init(table, opts) do
    ensure_started()

    config = Keyword.merge(config(), opts)
    copies = Keyword.get(config, :copies, :ram_copies)
    nodes = Keyword.get(config, :nodes, [node()])

    table_opts = [{:attributes, [:key, :value]}, {:type, :set}, {copies, nodes}]

    case :mnesia.create_table(table, table_opts) do
      {:atomic, :ok} ->
        :ok

      {:aborted, {:already_exists, ^table}} ->
        :ok

      {:aborted, reason} ->
        raise """
        EDA could not create the Mnesia cache table #{inspect(table)}: #{inspect(reason)}

        The most common cause is a name already taken by an ETS table. Mnesia backs a
        `ram_copies` table with an ETS table of the same name, and the default cache
        adapter owns exactly these names, so switching adapters after EDA has started
        cannot work. Set the adapter in config instead:

            config :eda, cache_adapter: EDA.Cache.Adapter.Mnesia

        For `:disc_copies`, also run `:mnesia.create_schema([node()])` once before start.
        """
    end

    wait_for(table, Keyword.get(config, :wait_timeout, 5_000))
  end

  @impl true
  def get(table, key) do
    case :mnesia.dirty_read(table, key) do
      [{^table, ^key, value}] -> value
      _other -> nil
    end
  end

  @impl true
  def put(table, key, value) do
    :mnesia.dirty_write({table, key, value})
    :ok
  end

  @impl true
  def delete(table, key) do
    :mnesia.dirty_delete(table, key)
    :ok
  end

  @impl true
  def all(table) do
    table
    |> :mnesia.dirty_match_object({table, :_, :_})
    |> Enum.map(fn {_table, _key, value} -> value end)
  end

  @impl true
  def count(table) do
    :mnesia.table_info(table, :size)
  rescue
    _error -> 0
  catch
    :exit, _reason -> 0
  end

  @impl true
  def match_prefix(table, prefix) do
    table
    |> :mnesia.dirty_match_object({table, {prefix, :_}, :_})
    |> Enum.map(fn {_table, _key, value} -> value end)
  end

  @impl true
  def delete_prefix(table, prefix) do
    entries = :mnesia.dirty_match_object(table, {table, {prefix, :_}, :_})

    for {_table, key, _value} <- entries do
      :mnesia.dirty_delete(table, key)
    end

    Enum.map(entries, fn {_table, {_prefix, sub}, _value} -> sub end)
  end

  defp ensure_started do
    case :mnesia.system_info(:is_running) do
      :yes -> :ok
      _other -> :mnesia.start()
    end
  end

  defp wait_for(table, timeout) do
    case :mnesia.wait_for_tables([table], timeout) do
      :ok ->
        :ok

      {:timeout, tables} ->
        Logger.warning("Mnesia cache tables not ready within #{timeout}ms: #{inspect(tables)}")
        :ok

      {:error, reason} ->
        Logger.error("Mnesia cache tables unavailable: #{inspect(reason)}")
        :ok
    end
  end

  defp config, do: Application.get_env(:eda, :cache_mnesia, [])
end
