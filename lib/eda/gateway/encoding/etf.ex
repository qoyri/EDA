defmodule EDA.Gateway.Encoding.ETF do
  @moduledoc """
  Erlang External Term Format encoding for Discord Gateway payloads.

  Binary format decoded natively by the BEAM via `:erlang.binary_to_term/1`,
  significantly faster than JSON parsing. Payloads are ~15-30% smaller.

  ## Normalization

  Discord's ETF payloads differ from JSON in two ways:

  - **Atom keys** — Map keys arrive as atoms (e.g. `:op`) instead of strings.
  - **Integer snowflakes** — Large IDs arrive as integers instead of strings.

  `normalize/1` deep-converts the decoded term so the result is identical to
  what `Jason.decode!/1` would produce. This means the rest of EDA sees no
  difference between ETF and JSON payloads.

  ## Security

  We use `:erlang.binary_to_term/1` without the `:safe` option because Discord
  may introduce new fields (= new atoms) at any time. With `:safe`, unknown atoms
  would crash the decoder. Since `normalize/1` immediately converts all atoms to
  strings, there is no long-term pollution of the atom table beyond the decode call.
  """

  @behaviour EDA.Gateway.Encoding

  # Integers from 2^48 up are snowflakes. The oldest IDs Discord serves are above 1.5e17 (2^57),
  # while every other integer it sends stays far below 2^48: colours (2^24), flags, member limits,
  # millisecond timestamps (2^41). The threshold used to be 2^22, which turned all of those into
  # strings on ETF while JSON kept them integers.
  @snowflake_min 281_474_976_710_656

  # Permission bitfields are strings in Discord's model, whatever their value.
  @bitfield_keys [:permissions, :allow, :deny, :app_permissions]

  # Field names EDA reads, turned into strings at compile time: normalizing a key then returns a
  # literal instead of allocating a new binary for every key of every event. Any other key still
  # goes through Atom.to_string/1, so the list only decides speed, never the result.
  @known_keys ~w(
    accent_color accessory account action action_type actions activities activity added_members
    afk_channel_id afk_timeout alert_system_message_id allow allow_list allow_multiselect animated
    animation_id animation_type answer_id answers app_permissions application application_commands
    application_id applied_tags approximate_guild_count approximate_member_count
    approximate_presence_count approximate_user_authorization_count approximate_user_install_count
    asset assets attachment_id attachment_size_limit attachments audit_log_entries author
    authorizing_integration_owners auto_moderation_rule_name auto_moderation_rule_trigger_type
    auto_moderation_rules autocomplete available available_tags avatar avatar_decoration_data
    badge banner banner_asset_id base_mix base_theme bio bitrate bot bot_id bot_public
    bot_require_code_grant burst_colors buttons by_month by_month_day by_n_weekday by_weekday
    by_year_day call canceled_at changes channel channel_id channel_ids channel_type channel_types
    channels choices chunk_count chunk_index client_status clip_created_at clip_participants code
    collectibles color colors communication_disabled_until component component_type components
    consumed content content_type context contexts count count_details country cover_image
    cover_sticker_id created_at creator creator_id current_period_end current_period_start
    custom_id custom_install_url custom_message d data deaf default default_auto_archive_duration
    default_channel_ids default_forum_layout default_member_permissions
    default_message_notifications default_reaction_emoji default_sort_order
    default_thread_rate_limit_per_user default_values delete_member_days deleted deny description
    description_localizations details details_url disabled discoverable_disabled discovery_splash
    discriminator display_name_styles divider dm_spam_detected_at dms_disabled_until duration
    duration_ms duration_seconds duration_secs edited_timestamp effect_id email embeds emoji
    emoji_id emoji_name emojis enable_emoticons enabled end ended_timestamp endpoint ends_at
    entitlement_ids entitlements entity_id entity_metadata entity_type ephemeral event_type
    event_webhooks_status event_webhooks_types event_webhooks_url exempt_channels exempt_roles
    expire_behavior expire_grace_period expires_at expiry explicit_content_filter
    fail_if_not_exists features fields file file_types filename flags flags_new focused font_id
    footer format_type frequency global_name gradient_angle guild guild_count guild_id
    guild_locale guild_scheduled_event guild_scheduled_event_id guild_scheduled_events guilds
    handler heartbeat_interval height hoist icon icon_hash icon_url id identity_enabled
    identity_guild_id ids image incidents_data inline install_params instance integration_id
    integration_type integration_types integration_types_config integrations interacted_message_id
    interaction_metadata interactions_endpoint_url interval invite_cover_image inviter
    invites_disabled_until is_dirty is_renewal items join_timestamp joined_at key keyword_filter
    label large large_image large_text large_url last_message_id last_pin_timestamp layout_type
    locale managed matched_content matched_keyword max_age max_length max_members max_presences
    max_stage_video_channel_users max_uses max_value max_values max_video_channel_users me
    me_burst me_voted media member member_count members members_removed membership_state
    mention_channels mention_everyone mention_raid_protection_enabled mention_roles
    mention_total_limit mentionable mentions message message_count message_id message_reference
    message_snapshots messages meta metadata mfa_enabled mfa_level min_length min_value min_values
    mode moderated mute name name_localizations nameplate new_value newly_created nick nonce
    not_found nsfw nsfw_level old_value op opcode options opus original_response_message_id owner
    owner_id owner_user_id pack_id palette parent_id participants party pending
    permission_overwrites permissions pinned placeholder placeholder_version poll poll_media
    position preferred_locale premium_progress_bar_enabled premium_since
    premium_subscription_count premium_tier premium_type presences presets primary_color
    primary_guild primary_sku_id privacy_level privacy_policy_url prompts provider proxy_icon_url
    proxy_url public_flags public_updates_channel_id raid_detected_at rate_limit_per_user
    reactions reason recipients recurrence_rule redirect_uris referenced_message regex_patterns
    region removed_member_ids renewal_sku_ids request_to_speak_timestamp require_colons required
    resolved results resume_gateway_url retry_after revoked role role_connections_verification_url
    role_id role_ids role_name role_subscription_data role_subscription_listing_id roles
    rtc_region rule_id rule_trigger_type rules_channel_id s safety_alerts_channel_id
    scheduled_end_time scheduled_start_time scopes secondary_color secrets self_deaf self_mute
    self_stream self_video serialized_source_guild session_id shard shard_count shard_id
    shared_client_theme single_select size sku_id sku_ids slug small_image small_text small_url
    sort_value sound_id sound_volume soundboard_sounds source_channel source_guild source_guild_id
    spacing splash spoiler ssrc stage_instances start starts_at state state_url status
    status_display_type sticker_items stickers style subscriber_count subscription_listing_id
    suppress synced_at syncing system system_channel_flags system_channel_id t tag tags
    target_application target_id target_message_id target_type target_user team team_id temporary
    terms_of_service_url tertiary_color text thread thread_metadata threads thumbnail tier_name
    timestamp timestamps title token topic total_message_sent total_months_subscribed
    trigger_metadata trigger_type triggering_interaction_metadata tts type unavailable
    unicode_emoji updated_at url usage_count user user_count user_id user_limit username users
    uses v value values vanity_url_code verification_level verified verify_key version video
    video_quality_mode voice_start_time voice_states volume waveform webhook_id webhooks
    welcome_channels welcome_screen widget_channel_id widget_enabled width will_reconnect
  )

  @doc "Decodes an ETF binary and normalizes atom keys and snowflake integers to strings."
  @impl true
  @spec decode(binary()) :: map()
  def decode(binary) do
    binary
    |> :erlang.binary_to_term()
    |> normalize()
  end

  @doc """
  Encodes a map as an ETF binary frame.

  Atom keys are converted to strings before encoding because Discord's ETF
  parser requires string (binary) keys — atom keys cause a 4002 close code.
  This mirrors what `Jason.encode!/1` does implicitly for JSON.
  """
  @impl true
  @spec encode(map()) :: {:binary, binary()}
  def encode(map) do
    {:binary, map |> stringify_keys() |> :erlang.term_to_binary()}
  end

  @doc ~s[Returns `"etf"` for the gateway URL query parameter.]
  @impl true
  @spec url_encoding() :: String.t()
  def url_encoding, do: "etf"

  @doc """
  Deep-converts an ETF-decoded term to match `Jason.decode!/1` output.

  - Atom map keys become strings
  - Atom values become strings (e.g. event type atoms)
  - Snowflakes (integers from 2^48) and permission bitfields become strings; every other
    integer stays one, as in JSON
  - Booleans and nil are preserved
  - Lists and nested maps are recursively normalized
  """
  @spec normalize(term()) :: term()
  def normalize(map) when is_map(map), do: :maps.from_list(pairs(:maps.to_list(map)))
  def normalize(list) when is_list(list), do: list(list)
  def normalize(int) when is_integer(int) and int >= @snowflake_min, do: Integer.to_string(int)

  def normalize(atom) when is_atom(atom) and atom not in [nil, true, false],
    do: Atom.to_string(atom)

  def normalize(other), do: other

  # Hand-written recursion over maps:to_list/1: faster than Map.new/2 or maps:fold/3 here.
  defp pairs([{k, v} | rest]) when k in @bitfield_keys and is_integer(v),
    do: [{key(k), Integer.to_string(v)} | pairs(rest)]

  defp pairs([{k, v} | rest]), do: [{key(k), normalize(v)} | pairs(rest)]
  defp pairs([]), do: []

  defp list([head | tail]), do: [normalize(head) | list(tail)]
  defp list([]), do: []

  for known <- @known_keys do
    defp key(unquote(String.to_atom(known))), do: unquote(known)
  end

  defp key(k) when is_atom(k), do: Atom.to_string(k)
  defp key(k) when is_binary(k), do: k
  defp key(k) when is_integer(k), do: Integer.to_string(k)

  defp stringify_keys(map) when is_map(map) do
    Map.new(map, fn {k, v} -> {to_string(k), stringify_keys(v)} end)
  end

  defp stringify_keys(list) when is_list(list), do: Enum.map(list, &stringify_keys/1)
  defp stringify_keys(other), do: other
end
