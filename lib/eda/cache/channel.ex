defmodule EDA.Cache.Channel do
  @moduledoc """
  ETS-based cache for Discord channels.

  Provides O(1) lookups for channel data.
  """

  use GenServer

  @table :eda_channels

  # Client API

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @doc """
  Gets a channel from the cache.
  """
  @spec get(String.t() | integer()) :: map() | nil
  def get(channel_id) do
    case :ets.lookup(@table, to_string(channel_id)) do
      [{_, channel}] -> channel
      [] -> nil
    end
  end

  @doc """
  Gets all cached channels.
  """
  @spec all() :: [map()]
  def all do
    :ets.tab2list(@table)
    |> Enum.map(fn {_, channel} -> channel end)
  end

  @doc """
  Gets all channels for a guild.
  """
  @spec for_guild(String.t() | integer()) :: [map()]
  def for_guild(guild_id) do
    guild_id = to_string(guild_id)

    all()
    |> Enum.filter(fn channel -> channel["guild_id"] == guild_id end)
  end

  @doc """
  Creates or replaces a channel in the cache.
  """
  @spec create(map()) :: map()
  def create(channel) do
    channel_id = to_string(channel["id"])
    :ets.insert(@table, {channel_id, channel})
    channel
  end

  @doc """
  Updates a channel in the cache.
  """
  @spec update(String.t() | integer(), map()) :: map() | nil
  def update(channel_id, updates) do
    channel_id = to_string(channel_id)

    case get(channel_id) do
      nil ->
        nil

      existing ->
        updated = Map.merge(existing, updates)
        :ets.insert(@table, {channel_id, updated})
        updated
    end
  end

  @doc """
  Deletes a channel from the cache.
  """
  @spec delete(String.t() | integer()) :: :ok
  def delete(channel_id) do
    :ets.delete(@table, to_string(channel_id))
    :ok
  end

  @doc """
  Returns the number of cached channels.
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
