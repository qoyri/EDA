defmodule EDA.Event do
  @moduledoc "Typed event structs for Discord Gateway events."

  @event_modules %{
    "READY" => EDA.Event.Ready,
    "GUILD_CREATE" => EDA.Event.GuildCreate,
    "GUILD_UPDATE" => EDA.Event.GuildUpdate,
    "GUILD_DELETE" => EDA.Event.GuildDelete,
    "CHANNEL_CREATE" => EDA.Event.ChannelCreate,
    "CHANNEL_UPDATE" => EDA.Event.ChannelUpdate,
    "CHANNEL_DELETE" => EDA.Event.ChannelDelete,
    "GUILD_MEMBER_ADD" => EDA.Event.GuildMemberAdd,
    "GUILD_MEMBER_UPDATE" => EDA.Event.GuildMemberUpdate,
    "GUILD_MEMBER_REMOVE" => EDA.Event.GuildMemberRemove,
    "GUILD_ROLE_CREATE" => EDA.Event.GuildRoleCreate,
    "GUILD_ROLE_UPDATE" => EDA.Event.GuildRoleUpdate,
    "GUILD_ROLE_DELETE" => EDA.Event.GuildRoleDelete,
    "VOICE_STATE_UPDATE" => EDA.Event.VoiceStateUpdate,
    "VOICE_SERVER_UPDATE" => EDA.Event.VoiceServerUpdate,
    "PRESENCE_UPDATE" => EDA.Event.PresenceUpdate,
    "MESSAGE_CREATE" => EDA.Event.MessageCreate,
    "MESSAGE_UPDATE" => EDA.Event.MessageUpdate,
    "MESSAGE_DELETE" => EDA.Event.MessageDelete,
    "GUILD_MEMBERS_CHUNK" => EDA.Event.GuildMembersChunk,
    "MESSAGE_DELETE_BULK" => EDA.Event.MessageDeleteBulk,
    "MESSAGE_REACTION_ADD" => EDA.Event.MessageReactionAdd,
    "MESSAGE_REACTION_REMOVE" => EDA.Event.MessageReactionRemove,
    "MESSAGE_REACTION_REMOVE_ALL" => EDA.Event.MessageReactionRemoveAll,
    "MESSAGE_REACTION_REMOVE_EMOJI" => EDA.Event.MessageReactionRemoveEmoji,
    "TYPING_START" => EDA.Event.TypingStart,
    "INTERACTION_CREATE" => EDA.Event.InteractionCreate,
    "CHANNEL_PINS_UPDATE" => EDA.Event.ChannelPinsUpdate,
    "GUILD_BAN_ADD" => EDA.Event.GuildBanAdd,
    "GUILD_BAN_REMOVE" => EDA.Event.GuildBanRemove,
    "INVITE_CREATE" => EDA.Event.InviteCreate,
    "INVITE_DELETE" => EDA.Event.InviteDelete,
    "THREAD_CREATE" => EDA.Event.ThreadCreate,
    "THREAD_UPDATE" => EDA.Event.ThreadUpdate,
    "THREAD_DELETE" => EDA.Event.ThreadDelete,
    "THREAD_LIST_SYNC" => EDA.Event.ThreadListSync,
    "THREAD_MEMBER_UPDATE" => EDA.Event.ThreadMemberUpdate,
    "THREAD_MEMBERS_UPDATE" => EDA.Event.ThreadMembersUpdate,
    "WEBHOOKS_UPDATE" => EDA.Event.WebhooksUpdate,
    "GUILD_SCHEDULED_EVENT_CREATE" => EDA.Event.GuildScheduledEventCreate,
    "GUILD_SCHEDULED_EVENT_UPDATE" => EDA.Event.GuildScheduledEventUpdate,
    "GUILD_SCHEDULED_EVENT_DELETE" => EDA.Event.GuildScheduledEventDelete,
    "GUILD_SCHEDULED_EVENT_USER_ADD" => EDA.Event.GuildScheduledEventUserAdd,
    "GUILD_SCHEDULED_EVENT_USER_REMOVE" => EDA.Event.GuildScheduledEventUserRemove,
    "GUILD_EMOJIS_UPDATE" => EDA.Event.GuildEmojisUpdate,
    "GUILD_STICKERS_UPDATE" => EDA.Event.GuildStickersUpdate,
    "GUILD_AUDIT_LOG_ENTRY_CREATE" => EDA.Event.GuildAuditLogEntryCreate,
    "STAGE_INSTANCE_CREATE" => EDA.Event.StageInstanceCreate,
    "STAGE_INSTANCE_UPDATE" => EDA.Event.StageInstanceUpdate,
    "STAGE_INSTANCE_DELETE" => EDA.Event.StageInstanceDelete,
    "AUTO_MODERATION_RULE_CREATE" => EDA.Event.AutoModRuleCreate,
    "AUTO_MODERATION_RULE_UPDATE" => EDA.Event.AutoModRuleUpdate,
    "AUTO_MODERATION_RULE_DELETE" => EDA.Event.AutoModRuleDelete,
    "AUTO_MODERATION_ACTION_EXECUTION" => EDA.Event.AutoModActionExecution,
    "MESSAGE_POLL_VOTE_ADD" => EDA.Event.MessagePollVoteAdd,
    "MESSAGE_POLL_VOTE_REMOVE" => EDA.Event.MessagePollVoteRemove,
    "VOICE_READY" => EDA.Event.VoiceReady,
    "VOICE_SPEAKING_START" => EDA.Event.VoiceSpeakingStart,
    "VOICE_SPEAKING_STOP" => EDA.Event.VoiceSpeakingStop,
    "VOICE_AUDIO" => EDA.Event.VoiceAudio,
    "VOICE_PLAYBACK_FINISHED" => EDA.Event.VoicePlaybackFinished,
    "VOICE_CHANNEL_STATUS_UPDATE" => EDA.Event.VoiceChannelStatusUpdate,
    "GUILD_AVAILABLE" => EDA.Event.GuildCreate,
    "GUILD_UNAVAILABLE" => EDA.Event.GuildDelete,
    "GATEWAY_CLOSE" => EDA.Event.GatewayClose,
    "SESSION_RESUMED" => EDA.Event.SessionResumed,
    "SHARD_READY" => EDA.Event.ShardReady,
    "ALL_SHARDS_READY" => EDA.Event.AllShardsReady
  }

  @type event() ::
          EDA.Event.Ready.t()
          | EDA.Event.GuildCreate.t()
          | EDA.Event.GuildUpdate.t()
          | EDA.Event.GuildDelete.t()
          | EDA.Event.ChannelCreate.t()
          | EDA.Event.ChannelUpdate.t()
          | EDA.Event.ChannelDelete.t()
          | EDA.Event.GuildMemberAdd.t()
          | EDA.Event.GuildMemberUpdate.t()
          | EDA.Event.GuildMemberRemove.t()
          | EDA.Event.GuildRoleCreate.t()
          | EDA.Event.GuildRoleUpdate.t()
          | EDA.Event.GuildRoleDelete.t()
          | EDA.Event.VoiceStateUpdate.t()
          | EDA.Event.VoiceServerUpdate.t()
          | EDA.Event.PresenceUpdate.t()
          | EDA.Event.MessageCreate.t()
          | EDA.Event.MessageUpdate.t()
          | EDA.Event.MessageDelete.t()
          | EDA.Event.GuildMembersChunk.t()
          | EDA.Event.MessageDeleteBulk.t()
          | EDA.Event.MessageReactionAdd.t()
          | EDA.Event.MessageReactionRemove.t()
          | EDA.Event.MessageReactionRemoveAll.t()
          | EDA.Event.MessageReactionRemoveEmoji.t()
          | EDA.Event.TypingStart.t()
          | EDA.Event.InteractionCreate.t()
          | EDA.Event.ChannelPinsUpdate.t()
          | EDA.Event.GuildBanAdd.t()
          | EDA.Event.GuildBanRemove.t()
          | EDA.Event.InviteCreate.t()
          | EDA.Event.InviteDelete.t()
          | EDA.Event.ThreadCreate.t()
          | EDA.Event.ThreadUpdate.t()
          | EDA.Event.ThreadDelete.t()
          | EDA.Event.ThreadListSync.t()
          | EDA.Event.ThreadMemberUpdate.t()
          | EDA.Event.ThreadMembersUpdate.t()
          | EDA.Event.WebhooksUpdate.t()
          | EDA.Event.GuildScheduledEventCreate.t()
          | EDA.Event.GuildScheduledEventUpdate.t()
          | EDA.Event.GuildScheduledEventDelete.t()
          | EDA.Event.GuildScheduledEventUserAdd.t()
          | EDA.Event.GuildScheduledEventUserRemove.t()
          | EDA.Event.GuildEmojisUpdate.t()
          | EDA.Event.GuildStickersUpdate.t()
          | EDA.Event.GuildAuditLogEntryCreate.t()
          | EDA.Event.StageInstanceCreate.t()
          | EDA.Event.StageInstanceUpdate.t()
          | EDA.Event.StageInstanceDelete.t()
          | EDA.Event.AutoModRuleCreate.t()
          | EDA.Event.AutoModRuleUpdate.t()
          | EDA.Event.AutoModRuleDelete.t()
          | EDA.Event.AutoModActionExecution.t()
          | EDA.Event.MessagePollVoteAdd.t()
          | EDA.Event.MessagePollVoteRemove.t()
          | EDA.Event.VoiceReady.t()
          | EDA.Event.VoiceSpeakingStart.t()
          | EDA.Event.VoiceSpeakingStop.t()
          | EDA.Event.VoiceAudio.t()
          | EDA.Event.VoicePlaybackFinished.t()
          | EDA.Event.VoiceChannelStatusUpdate.t()
          | EDA.Event.ShardReady.t()
          | EDA.Event.AllShardsReady.t()
          | EDA.Event.Raw.t()

  @doc "Converts a raw Discord event into a typed struct."
  @spec from_raw(String.t(), map()) :: event()
  def from_raw(event_type, data) do
    case Map.fetch(@event_modules, event_type) do
      {:ok, module} -> module.from_raw(data)
      :error -> EDA.Event.Raw.from_raw(event_type, data)
    end
  end
end
