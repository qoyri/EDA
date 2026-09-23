defmodule EDA.Cache.Guild do
  @moduledoc """
  ETS-based cache for Discord guilds.

  Provides O(1) lookups for guild data.
  """

  use GenServer

  @table :eda_guilds
  @cache_name :guilds

  # Client API

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @doc """
  Gets a guild from the cache, as an `EDA.Guild` holding the guild object alone: its roles,
  channels and members are in their own caches. `EDA.Guild.fetch/1` adds the roles, and asks
  Discord when the guild is not cached.
  """
  @spec get(String.t() | integer()) :: EDA.Guild.t() | nil
  def get(guild_id) do
    case adapter().get(@table, to_string(guild_id)) do
      nil ->
        :telemetry.execute([:eda, :cache, :miss], %{count: 1}, %{cache: @cache_name})
        nil

      guild ->
        :telemetry.execute([:eda, :cache, :hit], %{count: 1}, %{cache: @cache_name})
        guild
    end
  end

  @doc """
  Gets all cached guilds.
  """
  @spec all() :: [EDA.Guild.t()]
  def all do
    adapter().all(@table)
  end

  @doc """
  Creates or replaces a guild in the cache.
  """
  @spec create(map() | EDA.Guild.t()) :: EDA.Guild.t()
  def create(guild) do
    guild = to_struct(guild)
    guild_id = to_string(guild.id)

    case EDA.Cache.Policy.check(EDA.Cache.Config.policy(@cache_name), :guild, guild_id, guild) do
      :cache ->
        adapter().put(@table, guild_id, guild)
        EDA.Cache.Evictor.touch(@table, guild_id)
        :telemetry.execute([:eda, :cache, :write], %{count: 1}, %{cache: @cache_name})
        guild

      :skip ->
        :telemetry.execute([:eda, :cache, :skip], %{count: 1}, %{cache: @cache_name})
        guild
    end
  end

  @doc """
  Updates a guild in the cache.
  """
  @spec update(String.t() | integer(), map()) :: EDA.Guild.t() | nil
  def update(guild_id, updates) do
    guild_id = to_string(guild_id)

    case get(guild_id) do
      nil ->
        nil

      existing ->
        updated = EDA.Entity.patch(existing, updates)
        adapter().put(@table, guild_id, updated)
        updated
    end
  end

  @doc """
  Deletes a guild from the cache.
  """
  @spec delete(String.t() | integer()) :: :ok
  def delete(guild_id) do
    key = to_string(guild_id)
    adapter().delete(@table, key)
    EDA.Cache.Evictor.remove(@table, key)
    :ok
  end

  @doc """
  Returns the number of cached guilds.
  """
  @spec count() :: non_neg_integer()
  def count do
    adapter().count(@table)
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    :ok = adapter().init(@table, [])
    {:ok, %{table: @table}}
  end

  defp adapter, do: EDA.Cache.Adapter.current()

  defp to_struct(%EDA.Guild{} = guild), do: guild
  defp to_struct(raw) when is_map(raw), do: EDA.Guild.from_raw(raw)
end
