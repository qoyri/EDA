defmodule EDA.Cache.Channel do
  @moduledoc """
  ETS-based cache for Discord channels.

  Uses composite keys `{guild_id, channel_id}` for O(guild_size) lookups
  via `for_guild/1` instead of full table scans. A reverse index table
  maps `channel_id` to `guild_id` for efficient single-channel lookups.

  DM channels use `nil` as their `guild_id`.
  """

  use GenServer

  @table :eda_channels
  @index :eda_channels_index
  @cache_name :channels

  # Client API

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @doc """
  Gets a channel from the cache by channel ID.
  """
  @spec get(String.t() | integer()) :: map() | nil
  def get(channel_id) do
    channel_id = to_string(channel_id)

    case adapter().get(@index, channel_id) do
      nil ->
        :telemetry.execute([:eda, :cache, :miss], %{count: 1}, %{cache: @cache_name})
        nil

      key ->
        case adapter().get(@table, key) do
          nil ->
            :telemetry.execute([:eda, :cache, :miss], %{count: 1}, %{cache: @cache_name})
            nil

          channel ->
            :telemetry.execute([:eda, :cache, :hit], %{count: 1}, %{cache: @cache_name})
            channel
        end
    end
  end

  @doc """
  Gets all cached channels.
  """
  @spec all() :: [map()]
  def all do
    adapter().all(@table)
  end

  @doc """
  Gets all channels for a guild. O(guild_size) via match_object.
  """
  @spec for_guild(String.t() | integer()) :: [map()]
  def for_guild(guild_id) do
    guild_id = to_string(guild_id)

    adapter().match_prefix(@table, guild_id)
  end

  @doc """
  Creates or replaces a channel in the cache.
  """
  @spec create(map()) :: map()
  def create(channel) do
    channel_id = to_string(channel["id"])
    guild_id = if gid = channel["guild_id"], do: to_string(gid)
    key = {guild_id, channel_id}

    case EDA.Cache.Policy.check(EDA.Cache.Config.policy(@cache_name), :channel, key, channel) do
      :cache ->
        adapter().put(@table, key, channel)
        adapter().put(@index, channel_id, key)
        EDA.Cache.Evictor.touch(@table, key)
        :telemetry.execute([:eda, :cache, :write], %{count: 1}, %{cache: @cache_name})
        channel

      :skip ->
        :telemetry.execute([:eda, :cache, :skip], %{count: 1}, %{cache: @cache_name})
        channel
    end
  end

  @doc """
  Updates a channel in the cache.
  """
  @spec update(String.t() | integer(), map()) :: map() | nil
  def update(channel_id, updates) do
    case get(to_string(channel_id)) do
      nil ->
        nil

      existing ->
        updated = Map.merge(existing, updates)
        create(updated)
        updated
    end
  end

  @doc """
  Deletes a channel from the cache.
  """
  @spec delete(String.t() | integer()) :: :ok
  def delete(channel_id) do
    channel_id = to_string(channel_id)

    case adapter().get(@index, channel_id) do
      nil ->
        :ok

      key ->
        adapter().delete(@table, key)
        adapter().delete(@index, channel_id)
        EDA.Cache.Evictor.remove(@table, key)
    end

    :ok
  end

  @doc """
  Removes all channels for a guild.
  """
  @spec delete_guild(String.t() | integer()) :: :ok
  def delete_guild(guild_id) do
    guild_id = to_string(guild_id)

    # delete_prefix returns the removed sub-keys, so the index is cleaned
    # without a second scan.
    for channel_id <- adapter().delete_prefix(@table, guild_id) do
      adapter().delete(@index, channel_id)
    end

    :ok
  end

  @doc """
  Returns the number of cached channels.
  """
  @spec count() :: non_neg_integer()
  def count do
    adapter().count(@table)
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    :ok = adapter().init(@table, [])
    :ok = adapter().init(@index, [])
    {:ok, %{}}
  end

  defp adapter, do: EDA.Cache.Adapter.current()
end
