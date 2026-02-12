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

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @doc """
  Gets a user's voice state in a guild.
  """
  @spec get(String.t() | integer(), String.t() | integer()) :: map() | nil
  def get(guild_id, user_id) do
    key = {to_string(guild_id), to_string(user_id)}

    case :ets.lookup(@table, key) do
      [{_, voice_state}] -> voice_state
      [] -> nil
    end
  end

  @doc """
  Gets all voice states for a guild.
  """
  @spec for_guild(String.t() | integer()) :: [map()]
  def for_guild(guild_id) do
    guild_id = to_string(guild_id)

    :ets.match_object(@table, {{guild_id, :_}, :_})
    |> Enum.map(fn {_, vs} -> vs end)
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
        :ets.delete(@table, key)

      _channel_id ->
        voice_state = Map.put(data, "guild_id", guild_id)
        :ets.insert(@table, {key, voice_state})
    end

    :ok
  end

  @doc """
  Removes all voice states for a guild.
  """
  @spec delete_guild(String.t() | integer()) :: :ok
  def delete_guild(guild_id) do
    guild_id = to_string(guild_id)
    :ets.match_delete(@table, {{guild_id, :_}, :_})
    :ok
  end

  @doc """
  Returns the total number of cached voice states.
  """
  @spec count() :: non_neg_integer()
  def count do
    :ets.info(@table, :size)
  end

  @impl true
  def init(_opts) do
    table = :ets.new(@table, [:set, :public, :named_table, read_concurrency: true])
    {:ok, %{table: table}}
  end
end
