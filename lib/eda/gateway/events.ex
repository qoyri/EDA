defmodule EDA.Gateway.Events do
  @moduledoc """
  Handles dispatching Gateway events to consumers and updating caches.

  Every event that carries state is used to keep the ETS caches up-to-date
  in real time (JDA-style). The consumer callback runs asynchronously
  so it never blocks the gateway.
  """

  require Logger

  @doc """
  Dispatches an event to the configured consumer and updates caches.
  """
  @spec dispatch(String.t(), map()) :: :ok
  def dispatch(event_type, data) do
    # Update caches based on event type
    update_cache(event_type, data)

    # Emit telemetry
    :telemetry.execute(
      [:eda, :gateway, :event],
      %{count: 1},
      %{event_type: event_type}
    )

    # Dispatch to consumer
    case EDA.consumer() do
      nil ->
        :ok

      consumer ->
        event = {String.to_atom(event_type), data}

        Task.start(fn ->
          try do
            consumer.handle_event(event)
          rescue
            e ->
              Logger.error(
                "Consumer error handling #{event_type}: #{Exception.message(e)}\n#{Exception.format_stacktrace(__STACKTRACE__)}"
              )
          end
        end)
    end

    :ok
  end

  # ── READY ──────────────────────────────────────────────────────────

  defp update_cache("READY", data) do
    for guild <- data["guilds"] || [] do
      EDA.Cache.Guild.create(guild)
    end

    if user = data["user"] do
      EDA.Cache.User.create(user)
    end
  end

  # ── Guild lifecycle ────────────────────────────────────────────────

  defp update_cache("GUILD_CREATE", data) do
    guild_id = data["id"]
    EDA.Cache.Guild.create(data)
    cache_guild_channels(data["channels"])
    cache_guild_members(guild_id, data["members"])
    cache_guild_roles(guild_id, data["roles"])
    cache_guild_voice_states(guild_id, data["voice_states"])
    cache_guild_presences(guild_id, data["presences"])
  end

  defp update_cache("GUILD_UPDATE", data) do
    EDA.Cache.Guild.update(data["id"], data)
  end

  defp update_cache("GUILD_DELETE", data) do
    guild_id = data["id"]
    EDA.Cache.Guild.delete(guild_id)
    EDA.Cache.Role.delete_guild(guild_id)
    EDA.Cache.Member.delete_guild(guild_id)
    EDA.Cache.VoiceState.delete_guild(guild_id)
    EDA.Cache.Presence.delete_guild(guild_id)
  end

  # ── Channels ───────────────────────────────────────────────────────

  defp update_cache("CHANNEL_CREATE", data) do
    EDA.Cache.Channel.create(data)
  end

  defp update_cache("CHANNEL_UPDATE", data) do
    EDA.Cache.Channel.update(data["id"], data)
  end

  defp update_cache("CHANNEL_DELETE", data) do
    EDA.Cache.Channel.delete(data["id"])
  end

  # ── Members ────────────────────────────────────────────────────────

  defp update_cache("GUILD_MEMBER_ADD", data) do
    guild_id = data["guild_id"]

    if user = data["user"] do
      EDA.Cache.User.create(user)
    end

    EDA.Cache.Member.create(guild_id, data)
  end

  defp update_cache("GUILD_MEMBER_UPDATE", data) do
    guild_id = data["guild_id"]

    if user = data["user"] do
      EDA.Cache.User.create(user)
      EDA.Cache.Member.update(guild_id, user["id"], data)
    end
  end

  defp update_cache("GUILD_MEMBER_REMOVE", data) do
    if user = data["user"] do
      EDA.Cache.Member.delete(data["guild_id"], user["id"])
    end
  end

  # ── Roles ──────────────────────────────────────────────────────────

  defp update_cache("GUILD_ROLE_CREATE", data) do
    EDA.Cache.Role.create(data["guild_id"], data["role"])
  end

  defp update_cache("GUILD_ROLE_UPDATE", data) do
    role = data["role"]
    EDA.Cache.Role.create(data["guild_id"], role)
  end

  defp update_cache("GUILD_ROLE_DELETE", data) do
    EDA.Cache.Role.delete(data["role_id"])
  end

  # ── Voice States ───────────────────────────────────────────────────

  defp update_cache("VOICE_STATE_UPDATE", data) do
    guild_id = data["guild_id"]

    # Cache voice state for ALL users
    if guild_id do
      EDA.Cache.VoiceState.upsert(guild_id, data)
    end

    # Also cache member data if present
    if member = data["member"] do
      if user = member["user"] do
        EDA.Cache.User.create(user)
      end

      if guild_id do
        EDA.Cache.Member.create(guild_id, member)
      end
    end

    # Route to Voice system when the update is for our bot
    me = EDA.Cache.me()

    if me && data["user_id"] == me["id"] do
      EDA.Voice.voice_state_update(guild_id, data["session_id"])
    end
  end

  defp update_cache("VOICE_SERVER_UPDATE", data) do
    EDA.Voice.voice_server_update(data["guild_id"], data["token"], data["endpoint"])
  end

  # ── Presences ──────────────────────────────────────────────────────

  defp update_cache("PRESENCE_UPDATE", data) do
    if guild_id = data["guild_id"] do
      EDA.Cache.Presence.upsert(guild_id, data)
    end

    # Presence updates include partial user data
    if user = data["user"] do
      if user["username"] do
        EDA.Cache.User.create(user)
      end
    end
  end

  # ── Messages ───────────────────────────────────────────────────────

  defp update_cache("MESSAGE_CREATE", data) do
    if author = data["author"] do
      EDA.Cache.User.create(author)
    end

    # MESSAGE_CREATE in guilds includes a member object
    if member = data["member"] do
      if guild_id = data["guild_id"] do
        member_with_user = Map.put(member, "user", data["author"])
        EDA.Cache.Member.create(guild_id, member_with_user)
      end
    end
  end

  # ── Catch-all ──────────────────────────────────────────────────────

  defp update_cache(_event_type, _data), do: :ok

  # ── GUILD_CREATE helpers ───────────────────────────────────────────

  defp cache_guild_channels(nil), do: :ok

  defp cache_guild_channels(channels) do
    for channel <- channels, do: EDA.Cache.Channel.create(channel)
  end

  defp cache_guild_members(_, nil), do: :ok

  defp cache_guild_members(guild_id, members) do
    for member <- members do
      if user = member["user"], do: EDA.Cache.User.create(user)
      EDA.Cache.Member.create(guild_id, member)
    end
  end

  defp cache_guild_roles(_, nil), do: :ok

  defp cache_guild_roles(guild_id, roles) do
    for role <- roles, do: EDA.Cache.Role.create(guild_id, role)
  end

  defp cache_guild_voice_states(_, nil), do: :ok

  defp cache_guild_voice_states(guild_id, voice_states) do
    for vs <- voice_states, do: EDA.Cache.VoiceState.upsert(guild_id, vs)
  end

  defp cache_guild_presences(_, nil), do: :ok

  defp cache_guild_presences(guild_id, presences) do
    for presence <- presences, do: EDA.Cache.Presence.upsert(guild_id, presence)
  end
end
