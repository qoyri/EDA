defmodule EDA.Cache.Presence do
  @moduledoc """
  ETS-based cache for Discord presences.

  Tracks user status (online/idle/dnd/offline) and activities per guild.

  What Discord leaves out of a presence is cached as it arrives, so a missing custom status
  means what it means on `EDA.Event.PresenceUpdate`: the user's profile may simply be private.
  Keyed by `{guild_id, user_id}`.

  Requires the `guild_presences` privileged intent.
  Automatically populated from GUILD_CREATE and PRESENCE_UPDATE events.
  """

  use GenServer

  @table :eda_presences
  @cache_name :presences

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @doc """
  Gets a user's presence in a guild.
  """
  @spec get(String.t() | integer(), String.t() | integer()) :: EDA.Event.PresenceUpdate.t() | nil
  def get(guild_id, user_id) do
    key = {to_string(guild_id), to_string(user_id)}

    case adapter().get(@table, key) do
      presence when not is_nil(presence) ->
        :telemetry.execute([:eda, :cache, :hit], %{count: 1}, %{cache: @cache_name})
        presence

      nil ->
        :telemetry.execute([:eda, :cache, :miss], %{count: 1}, %{cache: @cache_name})
        nil
    end
  end

  @doc """
  Gets all presences for a guild.
  """
  @spec for_guild(String.t() | integer()) :: [EDA.Event.PresenceUpdate.t()]
  def for_guild(guild_id) do
    guild_id = to_string(guild_id)

    adapter().match_prefix(@table, guild_id)
  end

  @doc """
  Creates or updates a presence.
  """
  @spec upsert(String.t(), map()) :: :ok
  def upsert(guild_id, data) do
    guild_id = to_string(guild_id)

    presence = %{to_struct(data) | guild_id: guild_id}
    user_id = to_string(presence.user && presence.user.id)
    key = {guild_id, user_id}

    case EDA.Cache.Policy.check(
           EDA.Cache.Config.policy(@cache_name),
           :presence,
           key,
           presence
         ) do
      :cache ->
        adapter().put(@table, key, presence)
        EDA.Cache.Evictor.touch(@table, key)
        :telemetry.execute([:eda, :cache, :write], %{count: 1}, %{cache: @cache_name})

      :skip ->
        :telemetry.execute([:eda, :cache, :skip], %{count: 1}, %{cache: @cache_name})
    end

    :ok
  end

  @doc """
  Removes all presences for a guild.
  """
  @spec delete_guild(String.t() | integer()) :: :ok
  def delete_guild(guild_id) do
    guild_id = to_string(guild_id)
    adapter().delete_prefix(@table, guild_id)
    :ok
  end

  @doc """
  Returns the total number of cached presences.
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

  defp to_struct(%EDA.Event.PresenceUpdate{} = presence), do: presence
  defp to_struct(raw) when is_map(raw), do: EDA.Event.PresenceUpdate.from_raw(raw)
end
