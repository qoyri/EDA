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

    # Rewrite GUILD_CREATE → GUILD_AVAILABLE during startup loading
    effective_type = resolve_event_type(event_type, data)

    # Emit telemetry
    :telemetry.execute(
      [:eda, :gateway, :event],
      %{count: 1},
      %{event_type: effective_type}
    )

    # Dispatch to consumer
    case EDA.consumer() do
      nil ->
        :ok

      consumer ->
        struct = EDA.Event.from_raw(effective_type, data)
        event = {String.to_atom(effective_type), struct}
        dispatch_to_consumer(consumer, effective_type, event)
    end

    :ok
  end

  defp resolve_event_type("GUILD_CREATE", data) do
    guild_id = data["id"]

    cond do
      EDA.Gateway.ReadyTracker.loading?(guild_id) ->
        EDA.Gateway.ReadyTracker.guild_loaded(guild_id)
        "GUILD_AVAILABLE"

      ets_member?(:eda_unavailable_guilds, guild_id) ->
        :ets.delete(:eda_unavailable_guilds, guild_id)
        "GUILD_AVAILABLE"

      true ->
        "GUILD_CREATE"
    end
  end

  defp resolve_event_type("GUILD_DELETE", data) do
    if data["unavailable"] == true do
      "GUILD_UNAVAILABLE"
    else
      "GUILD_DELETE"
    end
  end

  defp resolve_event_type(type, _data), do: type

  defp ets_member?(table, key) do
    :ets.member(table, key)
  rescue
    ArgumentError -> false
  end

  defp dispatch_to_consumer(consumer, event_type, event) do
    counter = :persistent_term.get(:eda_event_task_counter)
    active = :counters.get(counter, 1)
    max = Application.get_env(:eda, :max_event_concurrency, 1000)

    if active >= max do
      Logger.warning("Event dispatch at capacity (#{active}), dropping #{event_type}")

      :telemetry.execute(
        [:eda, :gateway, :event_dropped],
        %{count: 1},
        %{event_type: event_type}
      )

      :ok
    else
      :counters.add(counter, 1, 1)

      Task.Supervisor.start_child(EDA.Gateway.TaskSupervisor, fn ->
        try do
          consumer.handle_event(event)
        rescue
          e ->
            Logger.error(
              "Consumer error handling #{event_type}: #{Exception.message(e)}\n#{Exception.format_stacktrace(__STACKTRACE__)}"
            )
        after
          :counters.sub(counter, 1, 1)
        end
      end)
    end
  end

  # ── READY ──────────────────────────────────────────────────────────

  defp update_cache("READY", data) do
    # Guild stubs from READY are incomplete (unavailable: true).
    # Full guild data arrives via GUILD_CREATE events — caching happens there.
    if user = data["user"] do
      EDA.Cache.User.create(user)
    end
  end

  # ── Guild lifecycle ────────────────────────────────────────────────

  defp update_cache("GUILD_CREATE", data) do
    guild_id = data["id"]
    EDA.Cache.Guild.create(data)
    cache_guild_channels(guild_id, data["channels"])
    cache_guild_members(guild_id, data["members"])
    cache_guild_roles(guild_id, data["roles"])
    cache_guild_voice_states(guild_id, data["voice_states"])
    cache_guild_presences(guild_id, data["presences"])
    maybe_auto_chunk(data)
  end

  defp update_cache("GUILD_UPDATE", data) do
    EDA.Cache.Guild.update(data["id"], data)
  end

  defp update_cache("GUILD_DELETE", data) do
    guild_id = data["id"]

    if data["unavailable"] == true do
      # Guild outage — don't purge cache, just mark as unavailable
      :ets.insert(:eda_unavailable_guilds, {guild_id})
      EDA.Cache.Guild.update(guild_id, %{"unavailable" => true})
    else
      # Bot removed from guild — purge cache
      :ets.delete(:eda_unavailable_guilds, guild_id)
      EDA.Cache.Guild.delete(guild_id)
      EDA.Cache.Role.delete_guild(guild_id)
      EDA.Cache.Member.delete_guild(guild_id)
      EDA.Cache.VoiceState.delete_guild(guild_id)
      EDA.Cache.Presence.delete_guild(guild_id)
    end
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
      Logger.debug(
        "VOICE_STATE_UPDATE for our bot: guild=#{guild_id} channel=#{data["channel_id"]} session_id=#{data["session_id"]}"
      )

      EDA.Voice.voice_state_update(guild_id, data["session_id"], data["channel_id"])
    end
  end

  defp update_cache("VOICE_SERVER_UPDATE", data) do
    Logger.debug("VOICE_SERVER_UPDATE: guild=#{data["guild_id"]} endpoint=#{data["endpoint"]}")

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

  # ── Member Chunks ────────────────────────────────────────────────────

  defp update_cache("GUILD_MEMBERS_CHUNK", data) do
    EDA.Gateway.MemberChunker.handle_chunk(data)
  end

  # ── Catch-all ──────────────────────────────────────────────────────

  defp update_cache(_event_type, _data), do: :ok

  # ── Auto-chunking ────────────────────────────────────────────────────

  defp maybe_auto_chunk(data) do
    guild_id = data["id"]
    member_count = data["member_count"] || 0
    members_received = length(data["members"] || [])

    if members_received < member_count and should_chunk?(guild_id) do
      EDA.Gateway.MemberChunker.request(guild_id)
    end
  end

  defp should_chunk?(guild_id) do
    case Application.get_env(:eda, :chunk_members, false) do
      true ->
        true

      false ->
        false

      :large ->
        true

      fun when is_function(fun, 1) ->
        fun.(guild_id)

      ids when is_list(ids) ->
        guild_id in ids or to_string(guild_id) in Enum.map(ids, &to_string/1)
    end
  end

  # ── GUILD_CREATE helpers ───────────────────────────────────────────

  defp cache_guild_channels(_guild_id, nil), do: :ok

  defp cache_guild_channels(guild_id, channels) do
    for channel <- channels do
      channel = Map.put_new(channel, "guild_id", to_string(guild_id))
      EDA.Cache.Channel.create(channel)
    end
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
