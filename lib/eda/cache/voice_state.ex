defmodule EDA.Cache.VoiceState do
  @moduledoc """
  ETS-based cache for Discord voice states.

  Tracks which users are in which voice channels, along with their
  mute/deaf state. Keyed by `{guild_id, user_id}` for O(1) lookups.

  Automatically populated from GUILD_CREATE and VOICE_STATE_UPDATE events.
  When a user leaves voice (channel_id is nil), their entry is removed.
  """

  use GenServer

  @table :eda_voice_states
  @cache_name :voice_states

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @doc """
  Gets a user's voice state in a guild.
  """
  @spec get(String.t() | integer(), String.t() | integer()) :: map() | nil
  def get(guild_id, user_id) do
    key = {to_string(guild_id), to_string(user_id)}

    case adapter().get(@table, key) do
      voice_state when not is_nil(voice_state) ->
        :telemetry.execute([:eda, :cache, :hit], %{count: 1}, %{cache: @cache_name})
        voice_state

      nil ->
        :telemetry.execute([:eda, :cache, :miss], %{count: 1}, %{cache: @cache_name})
        nil
    end
  end

  @doc """
  Gets all voice states for a guild.
  """
  @spec for_guild(String.t() | integer()) :: [map()]
  def for_guild(guild_id) do
    guild_id = to_string(guild_id)

    adapter().match_prefix(@table, guild_id)
  end

  @doc """
  Gets all voice states for a specific voice channel in a guild.
  """
  @spec for_channel(String.t() | integer(), String.t() | integer()) :: [map()]
  def for_channel(guild_id, channel_id) do
    guild_id = to_string(guild_id)
    channel_id = to_string(channel_id)

    for_guild(guild_id)
    |> Enum.filter(fn vs -> vs["channel_id"] == channel_id end)
  end

  @doc """
  Creates or updates a voice state. If `channel_id` is nil, removes the entry.
  """
  @spec upsert(String.t(), map()) :: :ok
  def upsert(guild_id, data) do
    guild_id = to_string(guild_id)
    user_id = to_string(data["user_id"])
    key = {guild_id, user_id}

    case data["channel_id"] do
      nil ->
        adapter().delete(@table, key)
        EDA.Cache.Evictor.remove(@table, key)

      _channel_id ->
        voice_state = Map.put(data, "guild_id", guild_id)

        case EDA.Cache.Policy.check(
               EDA.Cache.Config.policy(@cache_name),
               :voice_state,
               key,
               voice_state
             ) do
          :cache ->
            adapter().put(@table, key, voice_state)
            EDA.Cache.Evictor.touch(@table, key)
            :telemetry.execute([:eda, :cache, :write], %{count: 1}, %{cache: @cache_name})

          :skip ->
            :telemetry.execute([:eda, :cache, :skip], %{count: 1}, %{cache: @cache_name})
        end
    end

    :ok
  end

  @doc """
  Removes all voice states for a guild.
  """
  @spec delete_guild(String.t() | integer()) :: :ok
  def delete_guild(guild_id) do
    guild_id = to_string(guild_id)
    adapter().delete_prefix(@table, guild_id)
    :ok
  end

  @doc """
  Returns the total number of cached voice states.
  """
  @spec count() :: non_neg_integer()
  def count do
    adapter().count(@table)
  end

  @impl true
  def init(_opts) do
    :ok = adapter().init(@table, [])
    {:ok, %{table: @table}}
  end

  defp adapter, do: EDA.Cache.Adapter.current()
end
