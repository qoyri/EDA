defmodule EDA.Error do
  @moduledoc """
  Discord JSON error codes with bidirectional lookup and named constants.

  Discord API responses include numeric error codes that indicate why a request
  failed. This module provides O(1) lookup in both directions (code → name and
  name → code) via compiled maps, plus named constants for autocompletion and
  pattern matching.

  ## Categories

  | Range | Category |
  |-------|----------|
  | 0 | General |
  | 10xxx | Unknown Resource |
  | 20xxx | Action Prohibition |
  | 30xxx | Maximum Limits |
  | 40xxx | Authorization / Rate Limits |
  | 50xxx | Invalid State / Permissions |
  | 60xxx | Two-Factor Authentication |
  | 80xxx | User Lookup |
  | 90xxx | Reactions |
  | 110xxx | Application Availability |
  | 130xxx | API Overload |
  | 150xxx | Stage |
  | 160xxx | Threads |
  | 170xxx | Sticker Validation |
  | 180xxx | Scheduled Events |
  | 200xxx | Auto Moderation |
  | 220xxx | Webhook Forum |
  | 240xxx | Harmful Links |
  | 340xxx–350xxx | Onboarding |
  | 400xxx | File Uploads |
  | 500xxx | Bans |
  | 520xxx | Polls |
  | 530xxx | Provisional Accounts / OIDC |

  ## Examples

      iex> EDA.Error.name(50_013)
      :missing_permissions

      iex> EDA.Error.code(:missing_permissions)
      50_013

      iex> EDA.Error.message(50_013)
      "You lack permissions to perform that action"

      iex> EDA.Error.known?(99_999)
      false

      iex> EDA.Error.missing_permissions()
      50_013
  """

  @codes %{
    # ── General ──
    0 =>
      {:general_error, "General error (such as a malformed request body, amongst other things)"},

    # ── Unknown Resource (10xxx) ──
    10_001 => {:unknown_account, "Unknown account"},
    10_002 => {:unknown_application, "Unknown application"},
    10_003 => {:unknown_channel, "Unknown channel"},
    10_004 => {:unknown_guild, "Unknown guild"},
    10_005 => {:unknown_integration, "Unknown integration"},
    10_006 => {:unknown_invite, "Unknown invite"},
    10_007 => {:unknown_member, "Unknown member"},
    10_008 => {:unknown_message, "Unknown message"},
    10_009 => {:unknown_permission_overwrite, "Unknown permission overwrite"},
    10_010 => {:unknown_provider, "Unknown provider"},
    10_011 => {:unknown_role, "Unknown role"},
    10_012 => {:unknown_token, "Unknown token"},
    10_013 => {:unknown_user, "Unknown user"},
    10_014 => {:unknown_emoji, "Unknown emoji"},
    10_015 => {:unknown_webhook, "Unknown webhook"},
    10_016 => {:unknown_webhook_service, "Unknown webhook service"},
    10_020 => {:unknown_session, "Unknown session"},
    10_021 => {:unknown_asset, "Unknown asset"},
    10_026 => {:unknown_ban, "Unknown ban"},
    10_027 => {:unknown_sku, "Unknown SKU"},
    10_028 => {:unknown_store_listing, "Unknown Store Listing"},
    10_029 => {:unknown_entitlement, "Unknown entitlement"},
    10_030 => {:unknown_build, "Unknown build"},
    10_031 => {:unknown_lobby, "Unknown lobby"},
    10_032 => {:unknown_branch, "Unknown branch"},
    10_033 => {:unknown_store_directory_layout, "Unknown store directory layout"},
    10_036 => {:unknown_redistributable, "Unknown redistributable"},
    10_038 => {:unknown_gift_code, "Unknown gift code"},
    10_049 => {:unknown_stream, "Unknown stream"},
    10_050 =>
      {:unknown_premium_server_subscribe_cooldown, "Unknown premium server subscribe cooldown"},
    10_057 => {:unknown_guild_template, "Unknown guild template"},
    10_059 => {:unknown_discoverable_server_category, "Unknown discoverable server category"},
    10_060 => {:unknown_sticker, "Unknown sticker"},
    10_061 => {:unknown_sticker_pack, "Unknown sticker pack"},
    10_062 => {:unknown_interaction, "Unknown interaction"},
    10_063 => {:unknown_application_command, "Unknown application command"},
    10_065 => {:unknown_voice_state, "Unknown voice state"},
    10_066 =>
      {:unknown_application_command_permissions, "Unknown application command permissions"},
    10_067 => {:unknown_stage_instance, "Unknown Stage Instance"},
    10_068 => {:unknown_guild_member_verification_form, "Unknown Guild Member Verification Form"},
    10_069 => {:unknown_guild_welcome_screen, "Unknown Guild Welcome Screen"},
    10_070 => {:unknown_guild_scheduled_event, "Unknown Guild Scheduled Event"},
    10_071 => {:unknown_guild_scheduled_event_user, "Unknown Guild Scheduled Event User"},
    10_087 => {:unknown_tag, "Unknown Tag"},
    10_097 => {:unknown_sound, "Unknown sound"},
    10_124 => {:unknown_invite_target_users_job, "Unknown invite target users job"},
    10_129 => {:unknown_invite_target_users, "Unknown invite target users"},

    # ── Action Prohibition (20xxx) ──
    20_001 => {:bots_cannot_use, "Bots cannot use this endpoint"},
    20_002 => {:only_bots_can_use, "Only bots can use this endpoint"},
    20_009 =>
      {:explicit_content_blocked, "Explicit content cannot be sent to the desired recipient(s)"},
    20_012 =>
      {:not_authorized_for_application,
       "You are not authorized to perform this action on this application"},
    20_016 =>
      {:slowmode_rate_limit, "This action cannot be performed due to slowmode rate limit"},
    20_018 => {:only_owner, "Only the owner of this account can perform this action"},
    20_022 =>
      {:announcement_rate_limit, "This message cannot be edited due to announcement rate limits"},
    20_024 => {:under_minimum_age, "Under minimum age"},
    20_028 =>
      {:channel_write_rate_limit, "The channel you are writing has hit the write rate limit"},
    20_029 =>
      {:server_write_rate_limit,
       "The write action you are performing on the server has hit the write rate limit"},
    20_031 =>
      {:disallowed_words,
       "Your Stage topic, server name, server description, or channel names contain words that are not allowed"},
    20_035 => {:guild_premium_level_too_low, "Guild premium subscription level too low"},

    # ── Maximum Limits (30xxx) ──
    30_001 => {:max_guilds, "Maximum number of guilds reached (100)"},
    30_002 => {:max_friends, "Maximum number of friends reached (1000)"},
    30_003 => {:max_pins, "Maximum number of pins reached for the channel (50)"},
    30_004 => {:max_recipients, "Maximum number of recipients reached (10)"},
    30_005 => {:max_roles, "Maximum number of guild roles reached (250)"},
    30_007 => {:max_webhooks, "Maximum number of webhooks reached (15)"},
    30_008 => {:max_emojis, "Maximum number of emojis reached"},
    30_010 => {:max_reactions, "Maximum number of reactions reached (20)"},
    30_011 => {:max_group_dms, "Maximum number of group DMs reached (10)"},
    30_013 => {:max_guild_channels, "Maximum number of guild channels reached (500)"},
    30_015 => {:max_attachments, "Maximum number of attachments in a message reached (10)"},
    30_016 => {:max_invites, "Maximum number of invites reached (1000)"},
    30_018 => {:max_animated_emojis, "Maximum number of animated emojis reached"},
    30_019 => {:max_server_members, "Maximum number of server members reached"},
    30_030 =>
      {:max_server_categories, "Maximum number of server categories has been reached (5)"},
    30_031 => {:guild_already_has_template, "Guild already has a template"},
    30_032 => {:max_application_commands, "Maximum number of application commands reached"},
    30_033 =>
      {:max_thread_participants, "Maximum number of thread participants has been reached (1000)"},
    30_034 =>
      {:max_daily_application_command_creates,
       "Maximum number of daily application command creates has been reached (200)"},
    30_035 =>
      {:max_non_member_bans, "Maximum number of bans for non-guild members have been exceeded"},
    30_037 => {:max_ban_fetches, "Maximum number of bans fetches has been reached"},
    30_038 =>
      {:max_uncompleted_guild_scheduled_events,
       "Maximum number of uncompleted guild scheduled events reached (100)"},
    30_039 => {:max_stickers, "Maximum number of stickers reached"},
    30_040 =>
      {:max_prune_requests, "Maximum number of prune requests has been reached. Try again later"},
    30_042 =>
      {:max_guild_widget_updates,
       "Maximum number of guild widget settings updates has been reached. Try again later"},
    30_045 => {:max_soundboard_sounds, "Maximum number of soundboard sounds reached"},
    30_046 =>
      {:max_old_message_edits,
       "Maximum number of edits to messages older than 1 hour reached. Try again later"},
    30_047 =>
      {:max_pinned_threads,
       "Maximum number of pinned threads in a forum channel has been reached"},
    30_048 => {:max_forum_tags, "Maximum number of tags in a forum channel has been reached"},
    30_052 => {:bitrate_too_high, "Bitrate is too high for channel of this type"},
    30_056 => {:max_premium_emojis, "Maximum number of premium emojis reached (25)"},
    30_058 => {:max_guild_webhooks, "Maximum number of webhooks per guild reached (1000)"},
    30_060 =>
      {:max_channel_permission_overwrites,
       "Maximum number of channel permission overwrites reached (1000)"},
    30_061 => {:guild_channels_too_large, "The channels for this guild are too large"},

    # ── Authorization / Rate Limits (40xxx) ──
    40_001 => {:unauthorized, "Unauthorized. Provide a valid token and try again"},
    40_002 =>
      {:verify_account, "You need to verify your account in order to perform this action"},
    40_003 => {:dm_rate_limit, "You are opening direct messages too fast"},
    40_004 =>
      {:send_messages_temporarily_disabled, "Send messages has been temporarily disabled"},
    40_005 =>
      {:request_entity_too_large,
       "Request entity too large. Try sending something smaller in size"},
    40_006 =>
      {:feature_temporarily_disabled, "This feature has been temporarily disabled server-side"},
    40_007 => {:user_banned, "The user is banned from this guild"},
    40_012 => {:connection_revoked, "Connection has been revoked"},
    40_018 => {:only_consumable_skus, "Only consumable SKUs can be consumed"},
    40_019 => {:only_sandbox_entitlements, "You can only delete sandbox entitlements."},
    40_032 => {:target_user_not_connected, "Target user is not connected to voice"},
    40_033 => {:message_already_crossposted, "This message has already been crossposted"},
    40_041 =>
      {:application_command_name_exists, "An application command with that name already exists"},
    40_043 => {:application_interaction_failed, "Application interaction failed to send"},
    40_058 => {:cannot_send_in_forum, "Cannot send a message in a forum channel"},
    40_060 => {:interaction_already_acknowledged, "Interaction has already been acknowledged"},
    40_061 => {:tag_names_must_be_unique, "Tag names must be unique"},
    40_062 => {:service_resource_rate_limited, "Service resource is being rate limited"},
    40_066 =>
      {:no_non_moderator_tags, "There are no tags available that can be set by non-moderators"},
    40_067 =>
      {:tag_required_for_forum_post, "A tag is required to create a forum post in this channel"},
    40_074 =>
      {:entitlement_already_granted, "An entitlement has already been granted for this resource"},
    40_094 =>
      {:max_follow_up_messages,
       "This interaction has hit the maximum number of follow up messages"},
    40_333 =>
      {:cloudflare_blocking,
       "Cloudflare is blocking your request. This can often be resolved by setting a proper User Agent"},

    # ── Invalid State / Permissions (50xxx) ──
    50_001 => {:missing_access, "Missing access"},
    50_002 => {:invalid_account_type, "Invalid account type"},
    50_003 => {:cannot_execute_on_dm, "Cannot execute action on a DM channel"},
    50_004 => {:guild_widget_disabled, "Guild widget disabled"},
    50_005 => {:cannot_edit_other_user_message, "Cannot edit a message authored by another user"},
    50_006 => {:cannot_send_empty_message, "Cannot send an empty message"},
    50_007 => {:cannot_send_to_user, "Cannot send messages to this user"},
    50_008 => {:cannot_send_in_non_text, "Cannot send messages in a non-text channel"},
    50_009 =>
      {:channel_verification_too_high,
       "Channel verification level is too high for you to gain access"},
    50_010 => {:oauth2_no_bot, "OAuth2 application does not have a bot"},
    50_011 => {:oauth2_limit_reached, "OAuth2 application limit reached"},
    50_012 => {:invalid_oauth2_state, "Invalid OAuth2 state"},
    50_013 => {:missing_permissions, "You lack permissions to perform that action"},
    50_014 => {:invalid_auth_token, "Invalid authentication token provided"},
    50_015 => {:note_too_long, "Note was too long"},
    50_016 =>
      {:invalid_bulk_delete_count,
       "Provided too few or too many messages to delete. Must provide at least 2 and fewer than 100"},
    50_017 => {:invalid_mfa_level, "Invalid MFA Level"},
    50_019 => {:pin_wrong_channel, "A message can only be pinned to the channel it was sent in"},
    50_020 => {:invalid_or_taken_invite_code, "Invite code was either invalid or taken"},
    50_021 => {:cannot_execute_on_system_message, "Cannot execute action on a system message"},
    50_024 => {:cannot_execute_on_channel_type, "Cannot execute action on this channel type"},
    50_025 => {:invalid_oauth2_access_token, "Invalid OAuth2 access token provided"},
    50_026 => {:missing_oauth2_scope, "Missing required OAuth2 scope"},
    50_027 => {:invalid_webhook_token, "Invalid webhook token provided"},
    50_028 => {:invalid_role, "Invalid role"},
    50_033 => {:invalid_recipients, "Invalid Recipient(s)"},
    50_034 => {:message_too_old_to_bulk_delete, "A message provided was too old to bulk delete"},
    50_035 => {:invalid_form_body, "Invalid form body or invalid Content-Type provided"},
    50_036 =>
      {:invite_accepted_without_bot,
       "An invite was accepted to a guild the application's bot is not in"},
    50_039 => {:invalid_activity_action, "Invalid Activity Action"},
    50_041 => {:invalid_api_version, "Invalid API version provided"},
    50_045 => {:file_exceeds_max_size, "File uploaded exceeds the maximum size"},
    50_046 => {:invalid_file_uploaded, "Invalid file uploaded"},
    50_054 => {:cannot_self_redeem_gift, "Cannot self-redeem this gift"},
    50_055 => {:invalid_guild, "Invalid Guild"},
    50_057 => {:invalid_sku, "Invalid SKU"},
    50_067 => {:invalid_request_origin, "Invalid request origin"},
    50_068 => {:invalid_message_type, "Invalid message type"},
    50_070 => {:payment_source_required, "Payment source required to redeem gift"},
    50_073 => {:cannot_modify_system_webhook, "Cannot modify a system webhook"},
    50_074 =>
      {:cannot_delete_community_channel, "Cannot delete a channel required for Community guilds"},
    50_080 => {:cannot_edit_stickers_in_message, "Cannot edit stickers within a message"},
    50_081 => {:invalid_sticker_sent, "Invalid sticker sent"},
    50_083 =>
      {:operation_on_archived_thread,
       "Tried to perform an operation on an archived thread, such as editing or adding a user"},
    50_084 => {:invalid_thread_notification_settings, "Invalid thread notification settings"},
    50_085 =>
      {:before_earlier_than_thread_creation,
       "`before` value is earlier than the thread creation date"},
    50_086 =>
      {:community_channels_must_be_text, "Community server channels must be text channels"},
    50_091 =>
      {:event_entity_type_mismatch,
       "The entity type of the event differs from the entity you are trying to start"},
    50_095 =>
      {:server_not_available_in_location, "This server is not available in your location"},
    50_097 =>
      {:monetization_required, "This server needs monetization enabled to perform this action"},
    50_101 => {:more_boosts_required, "This server needs more boosts to perform this action"},
    50_109 => {:invalid_json, "The request body contains invalid JSON."},
    50_110 => {:invalid_file, "The provided file is invalid."},
    50_123 => {:invalid_file_type, "The provided file type is invalid."},
    50_124 =>
      {:file_duration_exceeds_max, "The provided file duration exceeds maximum of 5.2 seconds."},
    50_131 => {:owner_cannot_be_pending, "Owner cannot be pending member"},
    50_132 =>
      {:cannot_transfer_ownership_to_bot, "Ownership cannot be transferred to a bot user"},
    50_138 => {:failed_to_resize_asset, "Failed to resize asset below the maximum size: 262144"},
    50_144 =>
      {:cannot_mix_subscription_roles,
       "Cannot mix subscription and non subscription roles for an emoji"},
    50_145 =>
      {:cannot_convert_emoji_type, "Cannot convert between premium emoji and normal emoji"},
    50_146 => {:uploaded_file_not_found, "Uploaded file not found."},
    50_151 => {:invalid_emoji, "The specified emoji is invalid"},
    50_159 =>
      {:voice_messages_no_additional_content, "Voice messages do not support additional content."},
    50_160 =>
      {:voice_messages_single_audio, "Voice messages must have a single audio attachment."},
    50_161 =>
      {:voice_messages_must_have_metadata, "Voice messages must have supporting metadata."},
    50_162 => {:voice_messages_cannot_be_edited, "Voice messages cannot be edited."},
    50_163 =>
      {:cannot_delete_guild_subscription_integration,
       "Cannot delete guild subscription integration"},
    50_173 => {:cannot_send_voice_messages, "You cannot send voice messages in this channel."},
    50_178 => {:user_account_must_be_verified, "The user account must first be verified"},
    50_192 => {:invalid_file_duration, "The provided file does not have a valid duration."},
    50_600 =>
      {:no_permission_to_send_sticker, "You do not have permission to send this sticker."},

    # ── Two-Factor Authentication (60xxx) ──
    60_003 => {:two_factor_required, "Two factor is required for this operation"},

    # ── User Lookup (80xxx) ──
    80_004 => {:no_users_with_tag, "No users with DiscordTag exist"},

    # ── Reactions (90xxx) ──
    90_001 => {:reaction_blocked, "Reaction was blocked"},
    90_002 => {:cannot_use_burst_reactions, "User cannot use burst reactions"},

    # ── Application Availability (110xxx) ──
    110_000 => {:index_not_available, "Index not yet available. Try again later"},
    110_001 => {:application_not_available, "Application not yet available. Try again later"},

    # ── API Overload (130xxx) ──
    130_000 =>
      {:api_resource_overloaded, "API resource is currently overloaded. Try again a little later"},

    # ── Stage (150xxx) ──
    150_006 => {:stage_already_open, "The Stage is already open"},

    # ── Threads (160xxx) ──
    160_002 =>
      {:cannot_reply_without_read_history,
       "Cannot reply without permission to read message history"},
    160_004 =>
      {:thread_already_created_for_message, "A thread has already been created for this message"},
    160_005 => {:thread_locked, "Thread is locked"},
    160_006 => {:max_active_threads, "Maximum number of active threads reached"},
    160_007 =>
      {:max_active_announcement_threads, "Maximum number of active announcement threads reached"},
    160_009 =>
      {:cannot_reference_without_read_history,
       "Cannot reference a message without permission to read message history"},
    160_010 =>
      {:nsfw_message_reference_not_allowed, "NSFW channel message reference not allowed"},
    160_014 =>
      {:cannot_forward_unreadable_message,
       "You cannot forward a message whose content you cannot read"},

    # ── Sticker Validation (170xxx) ──
    170_001 => {:invalid_lottie_json, "Invalid JSON for uploaded Lottie file"},
    170_002 =>
      {:lottie_no_rasterized_images,
       "Uploaded Lotties cannot contain rasterized images such as PNG or JPEG"},
    170_003 => {:sticker_max_framerate_exceeded, "Sticker maximum framerate exceeded"},
    170_004 => {:sticker_max_frame_count, "Sticker frame count exceeds maximum of 1000 frames"},
    170_005 => {:lottie_max_dimensions, "Lottie animation maximum dimensions exceeded"},
    170_006 =>
      {:sticker_invalid_frame_rate, "Sticker frame rate is either too small or too large"},
    170_007 =>
      {:sticker_max_animation_duration, "Sticker animation duration exceeds maximum of 5 seconds"},

    # ── Scheduled Events (180xxx) ──
    180_000 => {:cannot_update_finished_event, "Cannot update a finished event"},
    180_002 =>
      {:failed_to_create_stage_for_event, "Failed to create stage needed for stage event"},

    # ── Auto Moderation (200xxx) ──
    200_000 => {:message_blocked_by_automod, "Message was blocked by automatic moderation"},
    200_001 => {:title_blocked_by_automod, "Title was blocked by automatic moderation"},

    # ── Webhook Forum (220xxx) ──
    220_001 =>
      {:webhook_forum_requires_thread,
       "Webhooks posted to forum channels must have a thread_name or thread_id"},
    220_002 =>
      {:webhook_forum_both_thread_fields,
       "Webhooks posted to forum channels cannot have both a thread_name and thread_id"},
    220_003 =>
      {:webhooks_can_only_create_forum_threads,
       "Webhooks can only create threads in forum channels"},
    220_004 =>
      {:webhook_services_cannot_use_forum, "Webhook services cannot be used in forum channels"},

    # ── Harmful Links (240xxx) ──
    240_000 =>
      {:message_blocked_by_harmful_links_filter, "Message blocked by harmful links filter"},

    # ── Onboarding (340xxx–350xxx) ──
    350_000 => {:cannot_enable_onboarding, "Cannot enable onboarding, requirements are not met"},
    350_001 => {:cannot_update_onboarding, "Cannot update onboarding while below requirements"},

    # ── File Uploads (400xxx) ──
    400_001 => {:file_uploads_limited, "Access to file uploads has been limited for this guild"},

    # ── Guild Features (670xxx) ──
    670_006 => {:missing_guild_feature, "Missing guild feature"},

    # ── Bans (500xxx) ──
    500_000 => {:failed_to_ban_users, "Failed to ban users"},

    # ── Polls (520xxx) ──
    520_000 => {:poll_voting_blocked, "Poll voting blocked"},
    520_001 => {:poll_expired, "Poll expired"},
    520_002 => {:invalid_channel_type_for_poll, "Invalid channel type for poll creation"},
    520_003 => {:cannot_edit_poll_message, "Cannot edit a poll message"},
    520_004 => {:cannot_use_emoji_in_poll, "Cannot use an emoji included with the poll"},
    520_006 => {:cannot_expire_non_poll, "Cannot expire a non-poll message"},

    # ── Provisional Accounts / OIDC (530xxx) ──
    530_000 =>
      {:no_provisional_account_permission,
       "Your Discord application has not been granted permission to use provisional accounts"},
    530_001 =>
      {:id_token_expired,
       "The ID token JWT you provided is expired. Get another issued from the identity provider"},
    530_002 =>
      {:id_token_issuer_mismatch,
       "The issuer in the ID token JWT does not match your configuration"},
    530_003 =>
      {:id_token_audience_mismatch,
       "The audience in the ID token JWT does not match the audience in OIDC configuration"},
    530_004 =>
      {:id_token_too_old,
       "The ID token was issued too long ago. Discord won't accept tokens older than a week"},
    530_006 =>
      {:failed_to_generate_username,
       "Discord failed to generate a unique username within allotted time. Retry"},
    530_007 =>
      {:invalid_client_secret, "Your client secret is invalid. Double check or regenerate it"}
  }

  @reverse Map.new(@codes, fn {code, {name, _msg}} -> {name, code} end)

  @doc "Returns the atom name for the given integer error code, or `nil` if unknown."
  @spec name(integer()) :: atom() | nil
  def name(code) when is_integer(code) do
    case Map.get(@codes, code) do
      {name, _msg} -> name
      nil -> nil
    end
  end

  @doc "Returns the integer error code for the given atom name, or `nil` if unknown."
  @spec code(atom()) :: integer() | nil
  def code(name) when is_atom(name) do
    Map.get(@reverse, name)
  end

  @doc "Returns the human-readable message for the given integer error code, or `nil` if unknown."
  @spec message(integer()) :: String.t() | nil
  def message(code) when is_integer(code) do
    case Map.get(@codes, code) do
      {_name, msg} -> msg
      nil -> nil
    end
  end

  @doc "Returns `true` if the given integer error code is a known Discord error code."
  @spec known?(integer()) :: boolean()
  def known?(code) when is_integer(code), do: Map.has_key?(@codes, code)

  @doc "Returns all known error codes as a map of `integer() => {atom(), String.t()}`."
  @spec all() :: %{integer() => {atom(), String.t()}}
  def all, do: @codes

  # ── Named Constants ──

  # ── General ──

  @doc "General error (0)."
  @spec general_error() :: 0
  def general_error, do: 0

  # ── Unknown Resource (10xxx) ──

  @doc "Unknown account (10001)."
  @spec unknown_account() :: 10_001
  def unknown_account, do: 10_001

  @doc "Unknown application (10002)."
  @spec unknown_application() :: 10_002
  def unknown_application, do: 10_002

  @doc "Unknown channel (10003)."
  @spec unknown_channel() :: 10_003
  def unknown_channel, do: 10_003

  @doc "Unknown guild (10004)."
  @spec unknown_guild() :: 10_004
  def unknown_guild, do: 10_004

  @doc "Unknown integration (10005)."
  @spec unknown_integration() :: 10_005
  def unknown_integration, do: 10_005

  @doc "Unknown invite (10006)."
  @spec unknown_invite() :: 10_006
  def unknown_invite, do: 10_006

  @doc "Unknown member (10007)."
  @spec unknown_member() :: 10_007
  def unknown_member, do: 10_007

  @doc "Unknown message (10008)."
  @spec unknown_message() :: 10_008
  def unknown_message, do: 10_008

  @doc "Unknown permission overwrite (10009)."
  @spec unknown_permission_overwrite() :: 10_009
  def unknown_permission_overwrite, do: 10_009

  @doc "Unknown provider (10010)."
  @spec unknown_provider() :: 10_010
  def unknown_provider, do: 10_010

  @doc "Unknown role (10011)."
  @spec unknown_role() :: 10_011
  def unknown_role, do: 10_011

  @doc "Unknown token (10012)."
  @spec unknown_token() :: 10_012
  def unknown_token, do: 10_012

  @doc "Unknown user (10013)."
  @spec unknown_user() :: 10_013
  def unknown_user, do: 10_013

  @doc "Unknown emoji (10014)."
  @spec unknown_emoji() :: 10_014
  def unknown_emoji, do: 10_014

  @doc "Unknown webhook (10015)."
  @spec unknown_webhook() :: 10_015
  def unknown_webhook, do: 10_015

  @doc "Unknown webhook service (10016)."
  @spec unknown_webhook_service() :: 10_016
  def unknown_webhook_service, do: 10_016

  @doc "Unknown session (10020)."
  @spec unknown_session() :: 10_020
  def unknown_session, do: 10_020

  @doc "Unknown asset (10021)."
  @spec unknown_asset() :: 10_021
  def unknown_asset, do: 10_021

  @doc "Unknown ban (10026)."
  @spec unknown_ban() :: 10_026
  def unknown_ban, do: 10_026

  @doc "Unknown SKU (10027)."
  @spec unknown_sku() :: 10_027
  def unknown_sku, do: 10_027

  @doc "Unknown Store Listing (10028)."
  @spec unknown_store_listing() :: 10_028
  def unknown_store_listing, do: 10_028

  @doc "Unknown entitlement (10029)."
  @spec unknown_entitlement() :: 10_029
  def unknown_entitlement, do: 10_029

  @doc "Unknown build (10030)."
  @spec unknown_build() :: 10_030
  def unknown_build, do: 10_030

  @doc "Unknown lobby (10031)."
  @spec unknown_lobby() :: 10_031
  def unknown_lobby, do: 10_031

  @doc "Unknown branch (10032)."
  @spec unknown_branch() :: 10_032
  def unknown_branch, do: 10_032

  @doc "Unknown store directory layout (10033)."
  @spec unknown_store_directory_layout() :: 10_033
  def unknown_store_directory_layout, do: 10_033

  @doc "Unknown redistributable (10036)."
  @spec unknown_redistributable() :: 10_036
  def unknown_redistributable, do: 10_036

  @doc "Unknown gift code (10038)."
  @spec unknown_gift_code() :: 10_038
  def unknown_gift_code, do: 10_038

  @doc "Unknown stream (10049)."
  @spec unknown_stream() :: 10_049
  def unknown_stream, do: 10_049

  @doc "Unknown premium server subscribe cooldown (10050)."
  @spec unknown_premium_server_subscribe_cooldown() :: 10_050
  def unknown_premium_server_subscribe_cooldown, do: 10_050

  @doc "Unknown guild template (10057)."
  @spec unknown_guild_template() :: 10_057
  def unknown_guild_template, do: 10_057

  @doc "Unknown discoverable server category (10059)."
  @spec unknown_discoverable_server_category() :: 10_059
  def unknown_discoverable_server_category, do: 10_059

  @doc "Unknown sticker (10060)."
  @spec unknown_sticker() :: 10_060
  def unknown_sticker, do: 10_060

  @doc "Unknown sticker pack (10061)."
  @spec unknown_sticker_pack() :: 10_061
  def unknown_sticker_pack, do: 10_061

  @doc "Unknown interaction (10062)."
  @spec unknown_interaction() :: 10_062
  def unknown_interaction, do: 10_062

  @doc "Unknown application command (10063)."
  @spec unknown_application_command() :: 10_063
  def unknown_application_command, do: 10_063

  @doc "Unknown voice state (10065)."
  @spec unknown_voice_state() :: 10_065
  def unknown_voice_state, do: 10_065

  @doc "Unknown application command permissions (10066)."
  @spec unknown_application_command_permissions() :: 10_066
  def unknown_application_command_permissions, do: 10_066

  @doc "Unknown Stage Instance (10067)."
  @spec unknown_stage_instance() :: 10_067
  def unknown_stage_instance, do: 10_067

  @doc "Unknown Guild Member Verification Form (10068)."
  @spec unknown_guild_member_verification_form() :: 10_068
  def unknown_guild_member_verification_form, do: 10_068

  @doc "Unknown Guild Welcome Screen (10069)."
  @spec unknown_guild_welcome_screen() :: 10_069
  def unknown_guild_welcome_screen, do: 10_069

  @doc "Unknown Guild Scheduled Event (10070)."
  @spec unknown_guild_scheduled_event() :: 10_070
  def unknown_guild_scheduled_event, do: 10_070

  @doc "Unknown Guild Scheduled Event User (10071)."
  @spec unknown_guild_scheduled_event_user() :: 10_071
  def unknown_guild_scheduled_event_user, do: 10_071

  @doc "Unknown Tag (10087)."
  @spec unknown_tag() :: 10_087
  def unknown_tag, do: 10_087

  @doc "Unknown sound (10097)."
  @spec unknown_sound() :: 10_097
  def unknown_sound, do: 10_097

  @doc "Unknown invite target users job (10124)."
  @spec unknown_invite_target_users_job() :: 10_124
  def unknown_invite_target_users_job, do: 10_124

  @doc "Unknown invite target users (10129)."
  @spec unknown_invite_target_users() :: 10_129
  def unknown_invite_target_users, do: 10_129

  # ── Action Prohibition (20xxx) ──

  @doc "Bots cannot use this endpoint (20001)."
  @spec bots_cannot_use() :: 20_001
  def bots_cannot_use, do: 20_001

  @doc "Only bots can use this endpoint (20002)."
  @spec only_bots_can_use() :: 20_002
  def only_bots_can_use, do: 20_002

  @doc "Explicit content blocked (20009)."
  @spec explicit_content_blocked() :: 20_009
  def explicit_content_blocked, do: 20_009

  @doc "Not authorized for application (20012)."
  @spec not_authorized_for_application() :: 20_012
  def not_authorized_for_application, do: 20_012

  @doc "Slowmode rate limit (20016)."
  @spec slowmode_rate_limit() :: 20_016
  def slowmode_rate_limit, do: 20_016

  @doc "Only the owner can perform this action (20018)."
  @spec only_owner() :: 20_018
  def only_owner, do: 20_018

  @doc "Announcement rate limit (20022)."
  @spec announcement_rate_limit() :: 20_022
  def announcement_rate_limit, do: 20_022

  @doc "Under minimum age (20024)."
  @spec under_minimum_age() :: 20_024
  def under_minimum_age, do: 20_024

  @doc "Channel write rate limit (20028)."
  @spec channel_write_rate_limit() :: 20_028
  def channel_write_rate_limit, do: 20_028

  @doc "Server write rate limit (20029)."
  @spec server_write_rate_limit() :: 20_029
  def server_write_rate_limit, do: 20_029

  @doc "Disallowed words in content (20031)."
  @spec disallowed_words() :: 20_031
  def disallowed_words, do: 20_031

  @doc "Guild premium subscription level too low (20035)."
  @spec guild_premium_level_too_low() :: 20_035
  def guild_premium_level_too_low, do: 20_035

  # ── Maximum Limits (30xxx) ──

  @doc "Maximum number of guilds reached (30001)."
  @spec max_guilds() :: 30_001
  def max_guilds, do: 30_001

  @doc "Maximum number of friends reached (30002)."
  @spec max_friends() :: 30_002
  def max_friends, do: 30_002

  @doc "Maximum number of pins reached (30003)."
  @spec max_pins() :: 30_003
  def max_pins, do: 30_003

  @doc "Maximum number of recipients reached (30004)."
  @spec max_recipients() :: 30_004
  def max_recipients, do: 30_004

  @doc "Maximum number of guild roles reached (30005)."
  @spec max_roles() :: 30_005
  def max_roles, do: 30_005

  @doc "Maximum number of webhooks reached (30007)."
  @spec max_webhooks() :: 30_007
  def max_webhooks, do: 30_007

  @doc "Maximum number of emojis reached (30008)."
  @spec max_emojis() :: 30_008
  def max_emojis, do: 30_008

  @doc "Maximum number of reactions reached (30010)."
  @spec max_reactions() :: 30_010
  def max_reactions, do: 30_010

  @doc "Maximum number of group DMs reached (30011)."
  @spec max_group_dms() :: 30_011
  def max_group_dms, do: 30_011

  @doc "Maximum number of guild channels reached (30013)."
  @spec max_guild_channels() :: 30_013
  def max_guild_channels, do: 30_013

  @doc "Maximum number of attachments reached (30015)."
  @spec max_attachments() :: 30_015
  def max_attachments, do: 30_015

  @doc "Maximum number of invites reached (30016)."
  @spec max_invites() :: 30_016
  def max_invites, do: 30_016

  @doc "Maximum number of animated emojis reached (30018)."
  @spec max_animated_emojis() :: 30_018
  def max_animated_emojis, do: 30_018

  @doc "Maximum number of server members reached (30019)."
  @spec max_server_members() :: 30_019
  def max_server_members, do: 30_019

  @doc "Maximum number of server categories reached (30030)."
  @spec max_server_categories() :: 30_030
  def max_server_categories, do: 30_030

  @doc "Guild already has a template (30031)."
  @spec guild_already_has_template() :: 30_031
  def guild_already_has_template, do: 30_031

  @doc "Maximum number of application commands reached (30032)."
  @spec max_application_commands() :: 30_032
  def max_application_commands, do: 30_032

  @doc "Maximum number of thread participants reached (30033)."
  @spec max_thread_participants() :: 30_033
  def max_thread_participants, do: 30_033

  @doc "Maximum daily application command creates reached (30034)."
  @spec max_daily_application_command_creates() :: 30_034
  def max_daily_application_command_creates, do: 30_034

  @doc "Maximum non-member bans exceeded (30035)."
  @spec max_non_member_bans() :: 30_035
  def max_non_member_bans, do: 30_035

  @doc "Maximum ban fetches reached (30037)."
  @spec max_ban_fetches() :: 30_037
  def max_ban_fetches, do: 30_037

  @doc "Maximum uncompleted guild scheduled events reached (30038)."
  @spec max_uncompleted_guild_scheduled_events() :: 30_038
  def max_uncompleted_guild_scheduled_events, do: 30_038

  @doc "Maximum number of stickers reached (30039)."
  @spec max_stickers() :: 30_039
  def max_stickers, do: 30_039

  @doc "Maximum prune requests reached (30040)."
  @spec max_prune_requests() :: 30_040
  def max_prune_requests, do: 30_040

  @doc "Maximum guild widget settings updates reached (30042)."
  @spec max_guild_widget_updates() :: 30_042
  def max_guild_widget_updates, do: 30_042

  @doc "Maximum soundboard sounds reached (30045)."
  @spec max_soundboard_sounds() :: 30_045
  def max_soundboard_sounds, do: 30_045

  @doc "Maximum old message edits reached (30046)."
  @spec max_old_message_edits() :: 30_046
  def max_old_message_edits, do: 30_046

  @doc "Maximum pinned threads in forum reached (30047)."
  @spec max_pinned_threads() :: 30_047
  def max_pinned_threads, do: 30_047

  @doc "Maximum forum tags reached (30048)."
  @spec max_forum_tags() :: 30_048
  def max_forum_tags, do: 30_048

  @doc "Bitrate too high for channel type (30052)."
  @spec bitrate_too_high() :: 30_052
  def bitrate_too_high, do: 30_052

  @doc "Maximum premium emojis reached (30056)."
  @spec max_premium_emojis() :: 30_056
  def max_premium_emojis, do: 30_056

  @doc "Maximum webhooks per guild reached (30058)."
  @spec max_guild_webhooks() :: 30_058
  def max_guild_webhooks, do: 30_058

  @doc "Maximum channel permission overwrites reached (30060)."
  @spec max_channel_permission_overwrites() :: 30_060
  def max_channel_permission_overwrites, do: 30_060

  @doc "Guild channels too large (30061)."
  @spec guild_channels_too_large() :: 30_061
  def guild_channels_too_large, do: 30_061

  # ── Authorization / Rate Limits (40xxx) ──

  @doc "Unauthorized (40001)."
  @spec unauthorized() :: 40_001
  def unauthorized, do: 40_001

  @doc "Account verification required (40002)."
  @spec verify_account() :: 40_002
  def verify_account, do: 40_002

  @doc "DM rate limit (40003)."
  @spec dm_rate_limit() :: 40_003
  def dm_rate_limit, do: 40_003

  @doc "Send messages temporarily disabled (40004)."
  @spec send_messages_temporarily_disabled() :: 40_004
  def send_messages_temporarily_disabled, do: 40_004

  @doc "Request entity too large (40005)."
  @spec request_entity_too_large() :: 40_005
  def request_entity_too_large, do: 40_005

  @doc "Feature temporarily disabled server-side (40006)."
  @spec feature_temporarily_disabled() :: 40_006
  def feature_temporarily_disabled, do: 40_006

  @doc "User is banned from guild (40007)."
  @spec user_banned() :: 40_007
  def user_banned, do: 40_007

  @doc "Connection has been revoked (40012)."
  @spec connection_revoked() :: 40_012
  def connection_revoked, do: 40_012

  @doc "Only consumable SKUs can be consumed (40018)."
  @spec only_consumable_skus() :: 40_018
  def only_consumable_skus, do: 40_018

  @doc "Only sandbox entitlements can be deleted (40019)."
  @spec only_sandbox_entitlements() :: 40_019
  def only_sandbox_entitlements, do: 40_019

  @doc "Target user not connected to voice (40032)."
  @spec target_user_not_connected() :: 40_032
  def target_user_not_connected, do: 40_032

  @doc "Message already crossposted (40033)."
  @spec message_already_crossposted() :: 40_033
  def message_already_crossposted, do: 40_033

  @doc "Application command name already exists (40041)."
  @spec application_command_name_exists() :: 40_041
  def application_command_name_exists, do: 40_041

  @doc "Application interaction failed to send (40043)."
  @spec application_interaction_failed() :: 40_043
  def application_interaction_failed, do: 40_043

  @doc "Cannot send a message in a forum channel (40058)."
  @spec cannot_send_in_forum() :: 40_058
  def cannot_send_in_forum, do: 40_058

  @doc "Interaction already acknowledged (40060)."
  @spec interaction_already_acknowledged() :: 40_060
  def interaction_already_acknowledged, do: 40_060

  @doc "Tag names must be unique (40061)."
  @spec tag_names_must_be_unique() :: 40_061
  def tag_names_must_be_unique, do: 40_061

  @doc "Service resource is being rate limited (40062)."
  @spec service_resource_rate_limited() :: 40_062
  def service_resource_rate_limited, do: 40_062

  @doc "No non-moderator tags available (40066)."
  @spec no_non_moderator_tags() :: 40_066
  def no_non_moderator_tags, do: 40_066

  @doc "Tag required for forum post (40067)."
  @spec tag_required_for_forum_post() :: 40_067
  def tag_required_for_forum_post, do: 40_067

  @doc "Entitlement already granted (40074)."
  @spec entitlement_already_granted() :: 40_074
  def entitlement_already_granted, do: 40_074

  @doc "Maximum follow-up messages reached (40094)."
  @spec max_follow_up_messages() :: 40_094
  def max_follow_up_messages, do: 40_094

  @doc "Cloudflare blocking request (40333)."
  @spec cloudflare_blocking() :: 40_333
  def cloudflare_blocking, do: 40_333

  # ── Invalid State / Permissions (50xxx) ──

  @doc "Missing access (50001)."
  @spec missing_access() :: 50_001
  def missing_access, do: 50_001

  @doc "Invalid account type (50002)."
  @spec invalid_account_type() :: 50_002
  def invalid_account_type, do: 50_002

  @doc "Cannot execute action on a DM channel (50003)."
  @spec cannot_execute_on_dm() :: 50_003
  def cannot_execute_on_dm, do: 50_003

  @doc "Guild widget disabled (50004)."
  @spec guild_widget_disabled() :: 50_004
  def guild_widget_disabled, do: 50_004

  @doc "Cannot edit another user's message (50005)."
  @spec cannot_edit_other_user_message() :: 50_005
  def cannot_edit_other_user_message, do: 50_005

  @doc "Cannot send an empty message (50006)."
  @spec cannot_send_empty_message() :: 50_006
  def cannot_send_empty_message, do: 50_006

  @doc "Cannot send messages to this user (50007)."
  @spec cannot_send_to_user() :: 50_007
  def cannot_send_to_user, do: 50_007

  @doc "Cannot send messages in a non-text channel (50008)."
  @spec cannot_send_in_non_text() :: 50_008
  def cannot_send_in_non_text, do: 50_008

  @doc "Channel verification level too high (50009)."
  @spec channel_verification_too_high() :: 50_009
  def channel_verification_too_high, do: 50_009

  @doc "OAuth2 application does not have a bot (50010)."
  @spec oauth2_no_bot() :: 50_010
  def oauth2_no_bot, do: 50_010

  @doc "OAuth2 application limit reached (50011)."
  @spec oauth2_limit_reached() :: 50_011
  def oauth2_limit_reached, do: 50_011

  @doc "Invalid OAuth2 state (50012)."
  @spec invalid_oauth2_state() :: 50_012
  def invalid_oauth2_state, do: 50_012

  @doc "Missing permissions (50013)."
  @spec missing_permissions() :: 50_013
  def missing_permissions, do: 50_013

  @doc "Invalid authentication token (50014)."
  @spec invalid_auth_token() :: 50_014
  def invalid_auth_token, do: 50_014

  @doc "Note too long (50015)."
  @spec note_too_long() :: 50_015
  def note_too_long, do: 50_015

  @doc "Invalid bulk delete message count (50016)."
  @spec invalid_bulk_delete_count() :: 50_016
  def invalid_bulk_delete_count, do: 50_016

  @doc "Invalid MFA level (50017)."
  @spec invalid_mfa_level() :: 50_017
  def invalid_mfa_level, do: 50_017

  @doc "Message pinned to wrong channel (50019)."
  @spec pin_wrong_channel() :: 50_019
  def pin_wrong_channel, do: 50_019

  @doc "Invalid or taken invite code (50020)."
  @spec invalid_or_taken_invite_code() :: 50_020
  def invalid_or_taken_invite_code, do: 50_020

  @doc "Cannot execute on system message (50021)."
  @spec cannot_execute_on_system_message() :: 50_021
  def cannot_execute_on_system_message, do: 50_021

  @doc "Cannot execute on this channel type (50024)."
  @spec cannot_execute_on_channel_type() :: 50_024
  def cannot_execute_on_channel_type, do: 50_024

  @doc "Invalid OAuth2 access token (50025)."
  @spec invalid_oauth2_access_token() :: 50_025
  def invalid_oauth2_access_token, do: 50_025

  @doc "Missing required OAuth2 scope (50026)."
  @spec missing_oauth2_scope() :: 50_026
  def missing_oauth2_scope, do: 50_026

  @doc "Invalid webhook token (50027)."
  @spec invalid_webhook_token() :: 50_027
  def invalid_webhook_token, do: 50_027

  @doc "Invalid role (50028)."
  @spec invalid_role() :: 50_028
  def invalid_role, do: 50_028

  @doc "Invalid recipient(s) (50033)."
  @spec invalid_recipients() :: 50_033
  def invalid_recipients, do: 50_033

  @doc "Message too old to bulk delete (50034)."
  @spec message_too_old_to_bulk_delete() :: 50_034
  def message_too_old_to_bulk_delete, do: 50_034

  @doc "Invalid form body or Content-Type (50035)."
  @spec invalid_form_body() :: 50_035
  def invalid_form_body, do: 50_035

  @doc "Invite accepted without bot in guild (50036)."
  @spec invite_accepted_without_bot() :: 50_036
  def invite_accepted_without_bot, do: 50_036

  @doc "Invalid Activity Action (50039)."
  @spec invalid_activity_action() :: 50_039
  def invalid_activity_action, do: 50_039

  @doc "Invalid API version (50041)."
  @spec invalid_api_version() :: 50_041
  def invalid_api_version, do: 50_041

  @doc "File exceeds maximum size (50045)."
  @spec file_exceeds_max_size() :: 50_045
  def file_exceeds_max_size, do: 50_045

  @doc "Invalid file uploaded (50046)."
  @spec invalid_file_uploaded() :: 50_046
  def invalid_file_uploaded, do: 50_046

  @doc "Cannot self-redeem gift (50054)."
  @spec cannot_self_redeem_gift() :: 50_054
  def cannot_self_redeem_gift, do: 50_054

  @doc "Invalid Guild (50055)."
  @spec invalid_guild() :: 50_055
  def invalid_guild, do: 50_055

  @doc "Invalid SKU (50057)."
  @spec invalid_sku() :: 50_057
  def invalid_sku, do: 50_057

  @doc "Invalid request origin (50067)."
  @spec invalid_request_origin() :: 50_067
  def invalid_request_origin, do: 50_067

  @doc "Invalid message type (50068)."
  @spec invalid_message_type() :: 50_068
  def invalid_message_type, do: 50_068

  @doc "Payment source required to redeem gift (50070)."
  @spec payment_source_required() :: 50_070
  def payment_source_required, do: 50_070

  @doc "Cannot modify a system webhook (50073)."
  @spec cannot_modify_system_webhook() :: 50_073
  def cannot_modify_system_webhook, do: 50_073

  @doc "Cannot delete community-required channel (50074)."
  @spec cannot_delete_community_channel() :: 50_074
  def cannot_delete_community_channel, do: 50_074

  @doc "Cannot edit stickers in a message (50080)."
  @spec cannot_edit_stickers_in_message() :: 50_080
  def cannot_edit_stickers_in_message, do: 50_080

  @doc "Invalid sticker sent (50081)."
  @spec invalid_sticker_sent() :: 50_081
  def invalid_sticker_sent, do: 50_081

  @doc "Operation on archived thread (50083)."
  @spec operation_on_archived_thread() :: 50_083
  def operation_on_archived_thread, do: 50_083

  @doc "Invalid thread notification settings (50084)."
  @spec invalid_thread_notification_settings() :: 50_084
  def invalid_thread_notification_settings, do: 50_084

  @doc "`before` value earlier than thread creation date (50085)."
  @spec before_earlier_than_thread_creation() :: 50_085
  def before_earlier_than_thread_creation, do: 50_085

  @doc "Community channels must be text channels (50086)."
  @spec community_channels_must_be_text() :: 50_086
  def community_channels_must_be_text, do: 50_086

  @doc "Event entity type mismatch (50091)."
  @spec event_entity_type_mismatch() :: 50_091
  def event_entity_type_mismatch, do: 50_091

  @doc "Server not available in location (50095)."
  @spec server_not_available_in_location() :: 50_095
  def server_not_available_in_location, do: 50_095

  @doc "Monetization required (50097)."
  @spec monetization_required() :: 50_097
  def monetization_required, do: 50_097

  @doc "More boosts required (50101)."
  @spec more_boosts_required() :: 50_101
  def more_boosts_required, do: 50_101

  @doc "Invalid JSON in request body (50109)."
  @spec invalid_json() :: 50_109
  def invalid_json, do: 50_109

  @doc "Invalid file (50110)."
  @spec invalid_file() :: 50_110
  def invalid_file, do: 50_110

  @doc "Invalid file type (50123)."
  @spec invalid_file_type() :: 50_123
  def invalid_file_type, do: 50_123

  @doc "File duration exceeds maximum (50124)."
  @spec file_duration_exceeds_max() :: 50_124
  def file_duration_exceeds_max, do: 50_124

  @doc "Owner cannot be pending member (50131)."
  @spec owner_cannot_be_pending() :: 50_131
  def owner_cannot_be_pending, do: 50_131

  @doc "Cannot transfer ownership to bot (50132)."
  @spec cannot_transfer_ownership_to_bot() :: 50_132
  def cannot_transfer_ownership_to_bot, do: 50_132

  @doc "Failed to resize asset (50138)."
  @spec failed_to_resize_asset() :: 50_138
  def failed_to_resize_asset, do: 50_138

  @doc "Cannot mix subscription and non-subscription roles for emoji (50144)."
  @spec cannot_mix_subscription_roles() :: 50_144
  def cannot_mix_subscription_roles, do: 50_144

  @doc "Cannot convert between premium and normal emoji (50145)."
  @spec cannot_convert_emoji_type() :: 50_145
  def cannot_convert_emoji_type, do: 50_145

  @doc "Uploaded file not found (50146)."
  @spec uploaded_file_not_found() :: 50_146
  def uploaded_file_not_found, do: 50_146

  @doc "Invalid emoji (50151)."
  @spec invalid_emoji() :: 50_151
  def invalid_emoji, do: 50_151

  @doc "Voice messages do not support additional content (50159)."
  @spec voice_messages_no_additional_content() :: 50_159
  def voice_messages_no_additional_content, do: 50_159

  @doc "Voice messages must have a single audio attachment (50160)."
  @spec voice_messages_single_audio() :: 50_160
  def voice_messages_single_audio, do: 50_160

  @doc "Voice messages must have supporting metadata (50161)."
  @spec voice_messages_must_have_metadata() :: 50_161
  def voice_messages_must_have_metadata, do: 50_161

  @doc "Voice messages cannot be edited (50162)."
  @spec voice_messages_cannot_be_edited() :: 50_162
  def voice_messages_cannot_be_edited, do: 50_162

  @doc "Cannot delete guild subscription integration (50163)."
  @spec cannot_delete_guild_subscription_integration() :: 50_163
  def cannot_delete_guild_subscription_integration, do: 50_163

  @doc "Cannot send voice messages in this channel (50173)."
  @spec cannot_send_voice_messages() :: 50_173
  def cannot_send_voice_messages, do: 50_173

  @doc "User account must be verified (50178)."
  @spec user_account_must_be_verified() :: 50_178
  def user_account_must_be_verified, do: 50_178

  @doc "Invalid file duration (50192)."
  @spec invalid_file_duration() :: 50_192
  def invalid_file_duration, do: 50_192

  @doc "No permission to send sticker (50600)."
  @spec no_permission_to_send_sticker() :: 50_600
  def no_permission_to_send_sticker, do: 50_600

  # ── Two-Factor Authentication (60xxx) ──

  @doc "Two-factor authentication required (60003)."
  @spec two_factor_required() :: 60_003
  def two_factor_required, do: 60_003

  # ── User Lookup (80xxx) ──

  @doc "No users with DiscordTag exist (80004)."
  @spec no_users_with_tag() :: 80_004
  def no_users_with_tag, do: 80_004

  # ── Reactions (90xxx) ──

  @doc "Reaction was blocked (90001)."
  @spec reaction_blocked() :: 90_001
  def reaction_blocked, do: 90_001

  @doc "User cannot use burst reactions (90002)."
  @spec cannot_use_burst_reactions() :: 90_002
  def cannot_use_burst_reactions, do: 90_002

  # ── Application Availability (110xxx) ──

  @doc "Search index not yet available (110000)."
  @spec index_not_available() :: 110_000
  def index_not_available, do: 110_000

  @doc "Application not yet available (110001)."
  @spec application_not_available() :: 110_001
  def application_not_available, do: 110_001

  # ── API Overload (130xxx) ──

  @doc "API resource currently overloaded (130000)."
  @spec api_resource_overloaded() :: 130_000
  def api_resource_overloaded, do: 130_000

  # ── Stage (150xxx) ──

  @doc "Stage is already open (150006)."
  @spec stage_already_open() :: 150_006
  def stage_already_open, do: 150_006

  # ── Threads (160xxx) ──

  @doc "Cannot reply without read message history permission (160002)."
  @spec cannot_reply_without_read_history() :: 160_002
  def cannot_reply_without_read_history, do: 160_002

  @doc "Thread already created for this message (160004)."
  @spec thread_already_created_for_message() :: 160_004
  def thread_already_created_for_message, do: 160_004

  @doc "Thread is locked (160005)."
  @spec thread_locked() :: 160_005
  def thread_locked, do: 160_005

  @doc "Maximum active threads reached (160006)."
  @spec max_active_threads() :: 160_006
  def max_active_threads, do: 160_006

  @doc "Maximum active announcement threads reached (160007)."
  @spec max_active_announcement_threads() :: 160_007
  def max_active_announcement_threads, do: 160_007

  @doc "Cannot reference a message without read message history permission (160009)."
  @spec cannot_reference_without_read_history() :: 160_009
  def cannot_reference_without_read_history, do: 160_009

  @doc "NSFW channel message reference not allowed (160010)."
  @spec nsfw_message_reference_not_allowed() :: 160_010
  def nsfw_message_reference_not_allowed, do: 160_010

  @doc "Cannot forward a message whose content the bot cannot read (160014)."
  @spec cannot_forward_unreadable_message() :: 160_014
  def cannot_forward_unreadable_message, do: 160_014

  # ── Sticker Validation (170xxx) ──

  @doc "Invalid Lottie JSON (170001)."
  @spec invalid_lottie_json() :: 170_001
  def invalid_lottie_json, do: 170_001

  @doc "Lottie cannot contain rasterized images (170002)."
  @spec lottie_no_rasterized_images() :: 170_002
  def lottie_no_rasterized_images, do: 170_002

  @doc "Sticker maximum framerate exceeded (170003)."
  @spec sticker_max_framerate_exceeded() :: 170_003
  def sticker_max_framerate_exceeded, do: 170_003

  @doc "Sticker frame count exceeds maximum (170004)."
  @spec sticker_max_frame_count() :: 170_004
  def sticker_max_frame_count, do: 170_004

  @doc "Lottie maximum dimensions exceeded (170005)."
  @spec lottie_max_dimensions() :: 170_005
  def lottie_max_dimensions, do: 170_005

  @doc "Sticker frame rate invalid (170006)."
  @spec sticker_invalid_frame_rate() :: 170_006
  def sticker_invalid_frame_rate, do: 170_006

  @doc "Sticker animation duration exceeds maximum (170007)."
  @spec sticker_max_animation_duration() :: 170_007
  def sticker_max_animation_duration, do: 170_007

  # ── Scheduled Events (180xxx) ──

  @doc "Cannot update a finished event (180000)."
  @spec cannot_update_finished_event() :: 180_000
  def cannot_update_finished_event, do: 180_000

  @doc "Failed to create stage for stage event (180002)."
  @spec failed_to_create_stage_for_event() :: 180_002
  def failed_to_create_stage_for_event, do: 180_002

  # ── Auto Moderation (200xxx) ──

  @doc "Message blocked by automatic moderation (200000)."
  @spec message_blocked_by_automod() :: 200_000
  def message_blocked_by_automod, do: 200_000

  @doc "Title blocked by automatic moderation (200001)."
  @spec title_blocked_by_automod() :: 200_001
  def title_blocked_by_automod, do: 200_001

  # ── Webhook Forum (220xxx) ──

  @doc "Webhook forum post requires thread_name or thread_id (220001)."
  @spec webhook_forum_requires_thread() :: 220_001
  def webhook_forum_requires_thread, do: 220_001

  @doc "Webhook forum post cannot have both thread_name and thread_id (220002)."
  @spec webhook_forum_both_thread_fields() :: 220_002
  def webhook_forum_both_thread_fields, do: 220_002

  @doc "Webhooks can only create threads in forum channels (220003)."
  @spec webhooks_can_only_create_forum_threads() :: 220_003
  def webhooks_can_only_create_forum_threads, do: 220_003

  @doc "Webhook services cannot be used in forum channels (220004)."
  @spec webhook_services_cannot_use_forum() :: 220_004
  def webhook_services_cannot_use_forum, do: 220_004

  # ── Harmful Links (240xxx) ──

  @doc "Message blocked by harmful links filter (240000)."
  @spec message_blocked_by_harmful_links_filter() :: 240_000
  def message_blocked_by_harmful_links_filter, do: 240_000

  # ── Onboarding (340xxx–350xxx) ──

  @doc "Cannot enable onboarding, requirements not met (350000)."
  @spec cannot_enable_onboarding() :: 350_000
  def cannot_enable_onboarding, do: 350_000

  @doc "Cannot update onboarding while below requirements (350001)."
  @spec cannot_update_onboarding() :: 350_001
  def cannot_update_onboarding, do: 350_001

  # ── File Uploads (400xxx) ──

  @doc "File uploads limited for this guild (400001)."
  @spec file_uploads_limited() :: 400_001
  def file_uploads_limited, do: 400_001

  # ── Guild Features (670xxx) ──

  @doc """
  The guild lacks a feature required by the request (670006).

  Returned as HTTP 403. Observed when setting gradient or holographic role colours on a
  guild that is not eligible — see `EDA.Role.Colors`. The feature is **not** advertised in
  the guild's `features` array, so there is nothing to check beforehand: attempt the call
  and handle this code.
  """
  @spec missing_guild_feature() :: 670_006
  def missing_guild_feature, do: 670_006

  # ── Bans (500xxx) ──

  @doc "Failed to ban users (500000)."
  @spec failed_to_ban_users() :: 500_000
  def failed_to_ban_users, do: 500_000

  # ── Polls (520xxx) ──

  @doc "Poll voting blocked (520000)."
  @spec poll_voting_blocked() :: 520_000
  def poll_voting_blocked, do: 520_000

  @doc "Poll expired (520001)."
  @spec poll_expired() :: 520_001
  def poll_expired, do: 520_001

  @doc "Invalid channel type for poll creation (520002)."
  @spec invalid_channel_type_for_poll() :: 520_002
  def invalid_channel_type_for_poll, do: 520_002

  @doc "Cannot edit a poll message (520003)."
  @spec cannot_edit_poll_message() :: 520_003
  def cannot_edit_poll_message, do: 520_003

  @doc "Cannot use emoji included with poll (520004)."
  @spec cannot_use_emoji_in_poll() :: 520_004
  def cannot_use_emoji_in_poll, do: 520_004

  @doc "Cannot expire a non-poll message (520006)."
  @spec cannot_expire_non_poll() :: 520_006
  def cannot_expire_non_poll, do: 520_006

  # ── Provisional Accounts / OIDC (530xxx) ──

  @doc "No permission to use provisional accounts (530000)."
  @spec no_provisional_account_permission() :: 530_000
  def no_provisional_account_permission, do: 530_000

  @doc "ID token JWT expired (530001)."
  @spec id_token_expired() :: 530_001
  def id_token_expired, do: 530_001

  @doc "ID token issuer mismatch (530002)."
  @spec id_token_issuer_mismatch() :: 530_002
  def id_token_issuer_mismatch, do: 530_002

  @doc "ID token audience mismatch (530003)."
  @spec id_token_audience_mismatch() :: 530_003
  def id_token_audience_mismatch, do: 530_003

  @doc "ID token too old (530004)."
  @spec id_token_too_old() :: 530_004
  def id_token_too_old, do: 530_004

  @doc "Failed to generate unique username (530006)."
  @spec failed_to_generate_username() :: 530_006
  def failed_to_generate_username, do: 530_006

  @doc "Invalid client secret (530007)."
  @spec invalid_client_secret() :: 530_007
  def invalid_client_secret, do: 530_007

  @doc """
  Whether a REST error means the thing asked for does not exist: an HTTP 404, or one of
  Discord's *Unknown …* codes (10001–10999), which is how it says so even when the status
  differs.

  Accepts the error term or the whole `{:error, term}` tuple.

      iex> EDA.Error.not_found?({:error, %{status: 404, code: 10_008, message: "Unknown Message"}})
      true

      iex> EDA.Error.not_found?(%{status: 403, code: 50_013, message: "Missing Permissions"})
      false
  """
  @spec not_found?(term()) :: boolean()
  def not_found?({:error, error}), do: not_found?(error)
  def not_found?(%{code: code}) when is_integer(code) and code in 10_000..10_999, do: true
  def not_found?(%{status: 404}), do: true
  def not_found?(_other), do: false
end
