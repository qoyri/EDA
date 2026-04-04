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
  Gets a guild from the cache as a raw map (string keys).

  This is the low-level cache accessor. For a typed `%EDA.Guild{}` struct,
  use `EDA.Guild.fetch/1` instead which parses the raw map automatically.
  """
  @spec get(String.t() | integer()) :: map() | nil
  def get(guild_id) do
    case :ets.lookup(@table, to_string(guild_id)) do
      [{_, guild}] ->
        :telemetry.execute([:eda, :cache, :hit], %{count: 1}, %{cache: @cache_name})
        guild

      [] ->
        :telemetry.execute([:eda, :cache, :miss], %{count: 1}, %{cache: @cache_name})
        nil
    end
  end

  @doc """
  Gets all cached guilds.
  """
  @spec all() :: [map()]
  def all do
    :ets.tab2list(@table)
    |> Enum.map(fn {_, guild} -> guild end)
  end

  @doc """
  Creates or replaces a guild in the cache.
  """
  @spec create(map()) :: map()
  def create(guild) do
    guild_id = to_string(guild["id"])

    case EDA.Cache.Policy.check(EDA.Cache.Config.policy(@cache_name), :guild, guild_id, guild) do
      :cache ->
        :ets.insert(@table, {guild_id, guild})
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
  @spec update(String.t() | integer(), map()) :: map() | nil
  def update(guild_id, updates) do
    guild_id = to_string(guild_id)

    case get(guild_id) do
      nil ->
        nil

      existing ->
        updated = Map.merge(existing, updates)
        :ets.insert(@table, {guild_id, updated})
        updated
    end
  end

  @doc """
  Deletes a guild from the cache.
  """
  @spec delete(String.t() | integer()) :: :ok
  def delete(guild_id) do
    key = to_string(guild_id)
    :ets.delete(@table, key)
    EDA.Cache.Evictor.remove(@table, key)
    :ok
  end

  @doc """
  Returns the number of cached guilds.
  """
  @spec count() :: non_neg_integer()
  def count do
    :ets.info(@table, :size)
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    table = :ets.new(@table, [:set, :public, :named_table, read_concurrency: true])
    {:ok, %{table: table}}
  end
end
