defmodule EDA.Cache.Guild do
  @moduledoc """
  ETS-based cache for Discord guilds.

  Provides O(1) lookups for guild data.
  """

  use GenServer

  @table :eda_guilds

  # Client API

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @doc """
  Gets a guild from the cache.
  """
  @spec get(String.t() | integer()) :: map() | nil
  def get(guild_id) do
    case :ets.lookup(@table, to_string(guild_id)) do
      [{_, guild}] -> guild
      [] -> nil
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
    :ets.insert(@table, {guild_id, guild})
    guild
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
    :ets.delete(@table, to_string(guild_id))
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
