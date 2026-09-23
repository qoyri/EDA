# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- **zstd-stream transport compression, on by default.** The gateway now asks Discord for
  `compress=zstd-stream` and decompresses in EDA's precompiled NIF: on the frames Discord sent to
  a real bot, 74 % less time than zlib-stream for a `GUILD_CREATE`, 46 % less for a small event
  (1.1 µs instead of 2.0). A bot without the NIF falls back to zlib-stream, and
  `config :eda, gateway_compression: :zlib` chooses it. Decompression errors emit
  `[:eda, :gateway, :zstd, :error]`, as zlib's emit `[:eda, :gateway, :zlib, :error]`.

### Changed

- **Less work per gateway event.** With a consumer, an event is parsed once and the caches take
  the struct, where they used to parse the payload again: a `GUILD_CREATE` went from 1.24 ms to
  0.7 ms on real guilds. `EDA.Collector` now receives an event only when a collector awaits its
  type; every event used to be copied to the collector process whether or not one did.
- **The consumer receives each event sooner.** Its handler runs in a process spawned directly,
  where a call to `Task.Supervisor.start_child/2` on every event took 5 µs and made one
  supervisor the queue of every shard. The handler still gets `$callers` and `$ancestors`, and
  when the application stops, EDA still waits up to five seconds for the handlers still running,
  as the supervisor did.
- **Faster ETF decoding.** Normalizing a payload returns the field names EDA knows as literals
  instead of allocating a new string for every key of every event: 10 to 20 % faster on every
  event type, a `GUILD_CREATE` normalized in 0.32 ms instead of 0.39.
- **Faster parsing.** Every entity's `from_raw/1`, nested ones included, reads the payload with a
  direct map lookup instead of going through `Access`: a message parses in 5.5 µs instead of 6.2,
  a member in 1.75 instead of 2.1, a role in 0.67 instead of 0.9.

Measured through the whole dispatch path on real events, these changes together bring a message
to about 13 µs instead of 19, a presence to 6.9 instead of 12, a role update to 4.8 instead of
8.5, and a `GUILD_CREATE` to 0.56 ms instead of 1.24.

### Fixed

- **Colours, flags and limits are integers on ETF, as on JSON.** The default ETF encoding turned
  every integer from 2^22 into a string, taking it for a snowflake: a role colour above `#400000`
  (half the roles of real guilds), an `accent_color`, flags with bit 22 set, a guild's
  `max_members`, and more, arrived as `"13566001"` where JSON gave `13566001`. Only snowflakes,
  from 2^48, and permission bitfields become strings now; on real payloads ETF and JSON decode to
  the same maps.
- **`from_raw/1` on a struct it already returned now gives it back unchanged.** It parsed the
  struct again and lost what it held in nested structs: a message's author, a member's user,
  a channel's voice and forum settings. Helpers that read the struct cache, such as
  `EDA.Channel.children/1`, went through that path.

## [0.5.0-beta.3] - 2026-09-23

The third beta reworks EDA's model of Discord from end to end, and breaks a lot on purpose, before
0.5.0 settles it. Everything Discord sends is typed down to the leaves, with dates as `DateTime`,
enumerations as atoms and flags decoded, and no documented field is dropped. An event whose
payload is an entity delivers that entity. The builders make the same structs a bot receives.
`EDA.API.*` is the raw layer everywhere, and every endpoint has a typed call on its entity. The
caches hold structs: a cached member is read five times faster. Over a hundred helpers cover
moderation, images, messages, guild limits and markdown.

### Installation

```elixir
def deps do
  [
    {:eda, "~> 0.5.0-beta.3"}
  ]
end
```

### Upgrading from 0.4 or an earlier beta

Most of what a bot touches changed shape. The list below is what to look for in your code; the
sections after it give every detail.

- **Events deliver the entity.** Match `{:MESSAGE_CREATE, %EDA.Message{}}`,
  `{:GUILD_CREATE, %EDA.Guild{}}`, `{:GUILD_MEMBER_UPDATE, %EDA.Member{}}`,
  `{:CHANNEL_UPDATE, %EDA.Channel{}}`, `{:GUILD_ROLE_CREATE, %EDA.Role{}}` (with `guild_id`),
  `{:USER_UPDATE, %EDA.User{}}`, `{:VOICE_STATE_UPDATE, %EDA.VoiceState{}}`,
  `{:ENTITLEMENT_CREATE, %EDA.Entitlement{}}` and the like, instead of a wrapper such as
  `%EDA.Event.UserUpdate{user: user}`.
- **Dates are `DateTime`s** (`joined_at`, `timestamp`, `expires_at`, `created_at`…), not strings
  or Unix integers. `EDA.Timestamp.parse/1` reads a date from a raw payload.
- **Integer enumerations are atoms**, Discord's name in lowercase: a channel `type` is
  `:guild_text`, a message `type` `:reply`, a component `:button`, a button style `:primary`, a
  command `type` `:slash`. A value EDA does not know yet stays the integer. Calls that send one
  take the atom or the integer.
- **Nested objects are structs**: embeds (`EDA.Embed.Footer`…), components (one struct per
  kind), a message's reference, stickers, interaction metadata, an interaction's `data`
  (`EDA.Interaction.CommandData`, `ComponentData`, `ModalSubmitData`), role tags, activity
  parts, invite and webhook partial guilds and channels. A channel's kind-specific fields live
  in `thread`, `forum`, `voice` and `dm`.
- **`x["field"]` still reads any struct**, but returns what the struct holds: an atom, a
  `DateTime`, a nested struct. `%{"field" => _}` patterns on EDA's values no longer match.
- **The builders return structs**: `EDA.Component.button/2` an `EDA.Component.Button` with
  `style: :primary`, `EDA.Command.slash/2` an `EDA.Command` with `type: :slash`,
  `EDA.Embed.footer/3` an `EDA.Embed.Footer`. What is sent to Discord is unchanged.
- **`EDA.API.*` returns Discord's maps everywhere**; use the entity for structs.
  `EDA.API.Emoji`, `Sticker`, `AutoMod` and `GuildTemplate` used to return structs: call
  `EDA.Emoji.list/1`, `EDA.Sticker.fetch/1`, `EDA.AutoMod.list/1`, `EDA.GuildTemplate.fetch/1`.
  `EDA.API.Guild.audit_log/2` returns the raw log; `EDA.AuditLog.fetch_log/2` the struct.
- **The caches return structs**: `EDA.Cache.get_member/2` an `EDA.Member`, and so on. An
  admission policy receives the struct.
- **Interaction helpers**: `EDA.Interaction.component_type/1` returns an atom,
  `resolved/3` a struct, `edit_response/2` and `followup/2` an `EDA.Message`.
- **A presence's `status` is an atom** (`:online`…), and `client_status` is keyed by platform
  atoms.


### Added

- `EDA.Permission.missing/2`, the required flags a bitset lacks, and `any?/2`;
  `EDA.Team.member?/2`.

- Smaller helpers: `EDA.Channel.text?/1`, `voice?/1`, `category?/1`, `dm?/1`, `archived?/1`,
  `locked?/1`, `url/1` and `children/1` (a category's channels, from the cache);
  `EDA.Attachment.image?/1`, `video?/1`, `audio?/1` and `extension/1`;
  `EDA.VoiceState.muted?/1` and `deafened?/1`; `EDA.Activity.elapsed/2`, `remaining/2`,
  `large_image_url/1` and `small_image_url/1` (application assets, `mp:` and `spotify:`
  images); `EDA.Emoji.parse/1`; `EDA.Webhook.url/1`; `EDA.AuditLog.Entry.change/2`.

- `EDA.Markdown`: `escape/1` for user text, `bold/1`, `italic/1`, `underline/1`,
  `strikethrough/1`, `spoiler/1`, `code/1`, `code_block/2`, `quote_text/1`, `block_quote/1`,
  `header/2`, `subtext/1`, `masked_link/3` and `list/2`, and `split/2`, which cuts a long text
  into messages of at most 2000 characters at line breaks, then words.
- `EDA.Mention.slash_command/2..4`, a clickable command mention (`</name sub:id>`), and
  `message_link/3`.

- A guild's features and limits: `EDA.Guild.feature?/2` (`:community` or `"COMMUNITY"`),
  `max_file_size/1`, `max_bitrate/1`, `max_emojis/1` and `max_stickers/1`, from the boost level
  and the features that raise them (`VIP_REGIONS`, `MORE_EMOJI`, `MORE_STICKERS`);
  `everyone_role/1`, `sorted_roles/1` (highest first) and `me/1`, the bot's member.

- Reading a message: `EDA.Message.url/1` and `parse_link/1` (any of Discord's domains, `@me`
  for a DM), `mentions?/2` (a user, member, role or `:everyone`), `invites/1` (the invite codes
  it links to), `webhook?/1`, `system?/1`, `deletable?/1` (six system types cannot be deleted,
  per Discord's table) and `clean_content/1` (mentions written as names).

- How a member shows, and what the bot may do to them: `EDA.Member.display_name/1` (nickname,
  display name, username), `boosting?/1`, `roles/2` (their roles as structs, highest first) and
  `color/2`; `owner?/2`, `can_interact?/3` (Discord's hierarchy: the owner above all, then the
  highest role, against a member or a role), and the bot's `manageable?/2`, `kickable?/2`,
  `bannable?/2` and `moderatable?/2`, which add its permissions (an administrator is never
  moderatable). `EDA.Role.compare/2`, `above?/2`, `hex_color/1` and `editable?/1`. They read
  the guild, roles and members from the cache, and answer `false` when what they need is not
  there.

- Image URLs for everything that has one, with the `:format`, `:size` and `:animated` options
  of `EDA.User.avatar_url/2`: `EDA.User.default_avatar_url/1`, `display_avatar_url/2` and
  `banner_url/2`; `EDA.Member.avatar_url/2` and `banner_url/2` (the guild's own) and
  `display_avatar_url/2` (guild avatar, then account, then default); `EDA.Guild.banner_url/2`,
  `splash_url/2` and `discovery_splash_url/2`; `EDA.Role.icon_url/2`;
  `EDA.ScheduledEvent.cover_url/2`; `EDA.Team.icon_url/2`.

- `EDA.Ban`, a banned user and the reason, with `list/2`, `stream/2`, `fetch_ban/2`,
  `create/3`, `remove/2` and `bulk/3`.
- More typed calls: `EDA.Channel.create/3`, `start_thread/2` (from a message or not),
  `create_post/3`, `thread_member/2`, `thread_members/1`, `active_threads/1`,
  `archived_threads/3` and `stream_archived_threads/3`; `EDA.Member.list/2`, `search/3`,
  `stream/2` and `move_voice/3`, their members carrying `guild_id`; `EDA.Invite.list_channel/1`
  and `list_guild/1`; `EDA.Guild.integrations/1`, `welcome_screen/1`,
  `modify_welcome_screen/2`, `modify_incident_actions/2` and `preview/1`;
  `EDA.Role.modify_positions/2`; `EDA.User.me/0`, `modify_me/1`, `guilds/1` and
  `stream_guilds/1`; `EDA.VoiceState.fetch_state/2`.

- Typed calls for webhooks, scheduled events, stages, entitlements and soundboard sounds:
  `EDA.Webhook` (`create/2`, `list_channel/1`, `list_guild/1`, `fetch/1`, `modify/2`,
  `delete/1`, and `execute/2`, `fetch_message/2`, `edit_message/3`, `delete_message/2` with the
  webhook's token), `EDA.ScheduledEvent` (`list/2`, `fetch_event/3`, `create/2`, `modify/3`,
  `delete/2`, `subscribers/2` and `stream_subscribers/2` returning the new
  `EDA.ScheduledEvent.Subscriber`), `EDA.StageInstance` (`create/1`, `fetch/1`, `modify/2`,
  `delete/1`), `EDA.Entitlement` (`list/1`, `fetch/1`, `consume/1`, `create_test/1`,
  `delete_test/1`) and `EDA.SoundboardSound` (`create/2`, `modify/3`, `delete/3`).

- Typed message calls: `EDA.Message.list/2`, `history/3`, `stream/2`, `pinned/2`, `pins/2`
  (each pin with its `pinned_at` as a `DateTime`) and `forward/2`; `EDA.Poll.expire/1` and
  `voters/3`; `EDA.Reaction.users/3` and `stream_users/3`. They return `EDA.Message` and
  `EDA.User` structs where the `EDA.API` calls return Discord's maps.

- `EDA.User` has a `member` field, set on the users a guild message mentions: Discord attaches
  their partial member to each, which EDA used to drop. It is an `EDA.Member` with the
  message's `guild_id`, and `nil` on any other user.

- `EDA.SKU`, what an app sells, with `list/0` returning structs, `type` as an atom and
  `EDA.SKU.Flags` read by `flags/1` and `flag?/2`.

- `EDA.StageInstance`, a live stage as a struct, which `STAGE_INSTANCE_CREATE`, `_UPDATE` and
  `_DELETE` now deliver instead of structs of their own.

- `EDA.Timestamp`, which reads Discord's timestamps into `DateTime` structs: `parse/1` for the
  ISO 8601 dates, `from_unix/1` and `from_unix_ms/1` for the Unix times a few payloads carry. It
  reads the two shapes Discord uses by matching bytes, 3 to 4 times faster than
  `DateTime.from_iso8601/1`, and agreed with it on every one of 1366 real dates. Use it on the
  raw maps the cache holds.
- `EDA.Mention.timestamp/2` takes a `DateTime` as well as a Unix time.

- `EDA.ScheduledEvent`, the guild scheduled event as a struct, with its cover `image` and
  `recurrence_rule`.

- `EDA.Presence.platforms/1` says which platforms a user is connected from, off the
  `client_status` EDA already received and never exposed, with `status_on/2`, `on?/2` and the
  `desktop?/1`, `mobile?/1`, `web?/1` shorthands. They read a `PRESENCE_UPDATE` event, a cached
  presence or the raw map. Discord documents `:desktop`, `:mobile`, `:web` and `:vr`; `:embedded`
  is named too, since it is sent but not documented, and a platform added later comes back as its
  string rather than being dropped. A user offline or invisible has no platform, and the two are
  indistinguishable here.

- The invite target user endpoints Discord added on 2026-09-18: `EDA.API.Invite`, and
  `EDA.Invite` for structs, gained `add_target_user/2`, `remove_target_user/2`,
  `add_target_users/2` and `remove_target_users/2` (up to 1000 at a time). They change a list in
  place, and apply at once, where `update_target_users/2` replaces it through a CSV upload that
  Discord processes in the background.
- `EDA.User.Flags` names the badges on a profile, and `EDA.Member.Flags` what a member has done
  in a guild — both with the `to_list/1`, `has?/2`, `to_bit/1` and `to_bitset/1` of
  `EDA.Permission`. `EDA.User.badges/1`, `badge?/2`, `EDA.Member.flags/1` and `flag?/2` read them
  straight off a user or member, struct or raw map. Undocumented bits are skipped rather than
  guessed at, except `:active_developer`, whose badge exists and whose bit is stable.
- `EDA.User.avatar_decoration_url/2` and `EDA.User.nameplate_url/2`, beside `avatar_url/1` and
  `guild_tag_badge_url/2`. A decoration is PNG only, animated ones included; a nameplate has an
  animation (`.webm`, the default) and a still (`format: :static`), neither of which Discord
  lists in its CDN endpoints — both were checked against a live profile.
- `EDA.Member` carries `flags`, `avatar_decoration_data`, `collectibles`, and the guild it
  belongs to in `guild_id`, set by `EDA.Member.fetch_member/2` and by the member events.
- `display_name_styles` on users and members: the font, effect and colours of the name. Discord
  sends it on about one user in eight but does not document it; its colours arrive as integers
  or strings, and are integers in `EDA.User.DisplayNameStyles`.
- The other bitfields Discord sends get the same treatment: `EDA.Message.Flags` (crossposted,
  ephemeral, voice message, forwarded snapshot, components v2…), `EDA.Role.Flags`,
  `EDA.Guild.SystemChannelFlags` (which notices the system channel suppresses) and
  `EDA.Activity.Flags`, read off their entity by `EDA.Message.flags/1` and `flag?/2`,
  `EDA.Role.flags/1` and `flag?/2`, `EDA.Guild.system_channel_flags/1` and
  `system_channel_flag?/2`, `EDA.Activity.flags/1` and `flag?/2`. The integer stays in the
  struct, so a bit Discord adds later is not lost.

### Changed

- **The caches hold structs.** `EDA.Cache.get_guild/1` returns an `EDA.Guild`,
  `get_member/2` an `EDA.Member`, `get_channel/1` an `EDA.Channel`, and so on for users, roles,
  voice states and presences (`EDA.Event.PresenceUpdate`). Discord's payloads are parsed once,
  when they arrive, instead of on every read: `EDA.Member.fetch_member/2` on a cached member went
  from 3.2 µs to 0.6 µs, and an entry takes 15 to 30 % less memory (measured on 1196 members,
  roles and channels of real guilds). Partial updates go through the new
  `EDA.Entity.patch/2`: a field Discord sends is replaced, `null` clears it, a field it leaves
  out is kept. An admission policy receives the struct, and `EDA.Member.top_role/2` returns an
  `EDA.Role`. `x["field"]` still reads a struct, but a value is now what the struct holds: an
  atom for a channel type, a `DateTime` for a date. Fields Discord does not document (a guild's
  `region`, `lazy`…) are no longer kept.

- **`EDA.Interaction.edit_response/2` and `followup/2` return an `EDA.Message`** instead of the
  raw map, and `edit_followup/3` and `delete_followup/2` are new.

- **A presence's `status` is an atom** (`:online`, `:idle`, `:dnd`, `:offline`), like the
  statuses `EDA.Presence` sends, and `client_status` names its platforms and statuses:
  `%{desktop: :idle, mobile: :online}`. A platform or status Discord adds later stays its
  string. The `EDA.Presence` helpers read both this and the raw maps the cache holds.

- **The `EDA.Component` and `EDA.Modal` builders return the component structs**, the same a
  received message's components are read into: `button/2` an `EDA.Component.Button` with
  `style: :primary`, `separator/1` an `EDA.Component.Separator` with `spacing: :large`,
  `text_field/3` an `EDA.Component.TextInput` with `style: :short`, a select's
  `default_values` `{:user, id}` tuples, and so on. They encode to Discord's integers when
  sent, so nothing changes on the wire; code that read the builders' maps (`button.style == 1`)
  reads atoms now. `:emoji` also takes an `EDA.Emoji` or a bare Unicode string.
  `EDA.Component.FileUpload` gained `file_types`.

- **`EDA.Command` is also a registered command**, read by `from_raw/1`: it gained `id`,
  `application_id`, `guild_id`, `version`, `handler` and `integration_types`, and its `type`
  (`:slash`, `:user`, `:message`, `:primary_entry_point`) and `contexts` (`:guild`, `:bot_dm`,
  `:private_channel`) are atoms, in the builder too. `EDA.Command.Option` likewise: its `type`
  is an atom (`:string`, `:sub_command`…), `channel_types` channel type atoms, and `choices`
  `EDA.Command.Option.Choice` structs. `to_map/1` still sends Discord's integers.
  `integration_types/2` sets where a command can be installed. The typed calls are new:
  `list_global/0`, `list_guild/1`, `create_global/1`, `create_guild/2`, `edit_global/2`,
  `edit_guild/3`, `delete_global/1`, `delete_guild/2`, `bulk_overwrite_global/1`,
  `bulk_overwrite_guild/2` and `permissions/1,2`. An audit log's `application_commands` are
  `EDA.Command` structs.

- **`EDA.API.*` returns Discord's maps everywhere**, as its moduledocs said; the typed surface
  is the entity modules. `EDA.API.Emoji`, `Sticker`, `AutoMod` and `GuildTemplate` used to
  parse into structs, and `EDA.API.Guild.audit_log/2` into a hybrid map. Their typed
  equivalents are new: `EDA.Emoji` (`list/1`, `fetch_emoji/2`, `create/2`, `modify/3`,
  `delete/2`, and `list_application/0`, `fetch_application/1`, `create_application/2`,
  `rename_application/2`, `delete_application/1`), `EDA.Sticker` (`list/1`, `fetch/1`,
  `fetch_sticker/2`, `create/2`, `modify/3`, `delete/2`, `list_packs/0`, `fetch_pack/1`),
  `EDA.AutoMod` (`list/1`, `fetch_rule/2`, `create/2`, `modify/3`, `delete/2`),
  `EDA.GuildTemplate` (`fetch/1`, `list/1`, `create/2`, `modify/3`, `sync/2`, `delete/2`,
  `create_guild/2` returning an `EDA.Guild`), and `EDA.AuditLog`, now a struct, with
  `fetch_log/2` returning every list it references as structs.

- **Every event whose payload is an entity delivers the entity**, not a struct wrapping it:
  `GUILD_ROLE_CREATE` and `_UPDATE` an `EDA.Role` (which gained `guild_id`, also set by a
  guild's `roles`, `fetch_role/2`, `create/3`, `modify/4` and `set_colors/4`),
  `VOICE_STATE_UPDATE` an `EDA.VoiceState`, `GUILD_SOUNDBOARD_SOUND_CREATE` and `_UPDATE` an
  `EDA.SoundboardSound`, `AUTO_MODERATION_RULE_*` an `EDA.AutoMod`, `USER_UPDATE` an
  `EDA.User`, `ENTITLEMENT_*` an `EDA.Entitlement`, `SUBSCRIPTION_*` an `EDA.Subscription`,
  `INTEGRATION_CREATE` and `_UPDATE` an `EDA.Integration`,
  `APPLICATION_COMMAND_PERMISSIONS_UPDATE` an `EDA.Command.Permissions`, and
  `THREAD_MEMBER_UPDATE` an `EDA.Channel.ThreadMember` (which gained `guild_id`). Match
  `{:USER_UPDATE, %EDA.User{} = user}` where you matched `%EDA.Event.UserUpdate{user: user}`.

- A guild template's source guild reads its `roles` and `channels` as `EDA.Role` and
  `EDA.Channel` structs (with the template's placeholder integer ids) and its levels as the
  atoms `EDA.Guild` uses.

- **`GUILD_AUDIT_LOG_ENTRY_CREATE` delivers an `EDA.AuditLog.Entry`**, which gained
  `guild_id`, instead of a struct of its own. An entry's `options` is an
  `EDA.AuditLog.Entry.Options`: the counts Discord sends as strings are integers, the
  overwrite `type` is `:role` or `:member`, the AutoMod trigger type an atom.

- **A scheduled event's `recurrence_rule` and `entity_metadata` are structs.**
  `EDA.ScheduledEvent.RecurrenceRule` names the frequency (`:weekly`…), weekdays (`:friday`)
  and months (`:july`), holds "the n-th weekday" as `{1, :friday}`, and its `start` and `end`
  are `DateTime`s. Both it and `EDA.ScheduledEvent.EntityMetadata` encode as Discord takes
  them, so they can be sent to `EDA.API.ScheduledEvent.create/2` and `modify/3`.

- **What a guild nests is structs**: `welcome_screen` an `EDA.Guild.WelcomeScreen` of
  `EDA.Guild.WelcomeScreen.Channel`s (both encode as Discord takes them), `incidents_data` an
  `EDA.Guild.IncidentsData` of `DateTime`s, and `GUILD_CREATE`'s `presences`,
  `stage_instances` and `guild_scheduled_events` lists of `EDA.Event.PresenceUpdate`,
  `EDA.StageInstance` and `EDA.ScheduledEvent`. `GUILD_MEMBERS_CHUNK`'s `presences` are
  `EDA.Event.PresenceUpdate` structs too, and its members and presences carry the `guild_id`.
  A forum's `default_reaction_emoji` is an `EDA.Channel.DefaultReaction`.

- **The partial objects other objects nest are their structs**: an invite's `guild`,
  `channel`, `target_application` and `guild_scheduled_event`; a webhook's `source_guild` and
  `source_channel`; an integration's `application` and `account`
  (`EDA.Integration.Account`); an attachment's `application`; an application's `guild` and
  `team`, the new `EDA.Team` with its `EDA.Team.Member`s; and `READY`'s `guilds` and
  `application`.

- **An interaction's `data` is a struct**, one per shape: `EDA.Interaction.CommandData` for a
  command or its autocomplete (`type` `:slash`, `:user`, `:message` or `:primary_entry_point`,
  `options` as `EDA.Interaction.Option`s with their `type` an atom), `ComponentData` for a
  button or a select, `ModalSubmitData` for a modal, whose components are `EDA.Component`
  structs, now including the modal ones (`Label`, `TextInput`, `FileUpload`, `RadioGroup`,
  `CheckboxGroup`, `Checkbox`). `resolved` is an `EDA.Resolved`. The `EDA.Interaction` and
  `EDA.Modal` helpers read the event or a raw interaction map alike;
  `EDA.Interaction.resolved/3` returns the struct and takes `:users`-style atoms as well as
  strings, and `component_type/1` returns the atom (`:button`, `:string_select`…).

- **A role's `tags` and an activity's parts are structs.** `EDA.Role.Tags` reads the keys
  Discord marks by sending them as `null` (`premium_subscriber`, `available_for_purchase`,
  `guild_connections`) as booleans. An activity's `timestamps` is an
  `EDA.Activity.Timestamps` of `DateTime`s, its `assets`, `party` and `secrets` are
  `EDA.Activity.Assets`, `Party` and `Secrets`.

- **Every object a message nests is a struct.** `message_reference` is an
  `EDA.Message.Reference` (`type` `:default` for a reply, `:forward` for a forward; it encodes
  as Discord takes it), `sticker_items` `EDA.Sticker.Item`s, `interaction_metadata` an
  `EDA.Message.InteractionMetadata` (named interaction type, users, nested triggering
  interaction), `call`, `activity`, `role_subscription_data`, `shared_client_theme` and
  `mention_channels` their `EDA.Message.*` structs, `application` an `EDA.App`, and
  `resolved` an `EDA.Resolved`, maps from id to struct with each member's user put back.
  `message_snapshots` is a list of partial `EDA.Message` structs, without Discord's `message`
  wrapper, and `channel_type` an atom.

- **A message's components are structs**, one per kind: `EDA.Component.ActionRow`, `Button`,
  `SelectMenu` (with its `SelectOption`s), `Section`, `TextDisplay`, `Thumbnail`,
  `MediaGallery`, `File`, `Separator` and `Container`, their images an `EDA.Component.Media`.
  Each has its `type` as an atom and the `id` Discord gives it; a button's `style`, a
  separator's `spacing`, a select's `channel_types` are atoms, its `default_values`
  `{:user, id}`-style tuples. A kind EDA does not know yet stays the raw map. They encode to
  JSON as Discord takes them, so `EDA.Component.disable_all/1`, which now reaches a section's
  accessory, can take a received message's components and send them back.
  `EDA.Component.from_raw/1` and `to_raw/1` are public.

- **A message's embeds are `EDA.Embed` structs**, down to their parts: `EDA.Embed.Footer`,
  `Author`, `Field`, `Media` (image, thumbnail and video, with the size, content type and
  placeholder Discord adds) and `Provider`. `EDA.Embed` gained `type` (`:rich`, `:video`,
  `:link`…), `video`, `provider` and `flags`, and `from_raw/1`. The builder builds the same
  structs, so `embed.footer.text` reads either; `timestamp` is a `DateTime` in both. A received
  embed can be sent again: `to_map/1` leaves out what only Discord sets.

- **The enumerations that had a helper are atoms in the struct too**, the helper taking the atom
  as well: `EDA.Invite` `type` and `target_type`, `EDA.Subscription.status`,
  `EDA.User.premium_type`, the `type` of `INTERACTION_CREATE` (with the names
  `EDA.Interaction.interaction_type/1` already used: `:command`, `:component`, `:autocomplete`,
  `:modal_submit`, `:ping`), and an audit log entry's `action_type`
  (`EDA.AuditLog.action_name/1`'s names).
- **AutoMod**: a rule's `event_type` (`:message_send`, `:member_update`) and `trigger_type`
  (`:keyword`, `:spam`, `:keyword_preset`, `:mention_spam`, `:member_profile`), an action's `type`
  (`:block_message`, `:send_alert_message`, `:timeout`, `:block_member_interaction`), the keyword
  `presets` (`:profanity`, `:sexual_content`, `:slurs`) and the execution event's
  `rule_trigger_type` are atoms. The action constructors build them, and `to_map/1` and
  `EDA.API.AutoMod.create/2` and `modify/3` send Discord's integers, whether given atoms, integers,
  structs or maps.

- **More enumerations are atoms**, Discord's names in lowercase, an unknown value staying the
  integer: `EDA.Message.type` (`:default`, `:reply`, `:chat_input_command`, `:thread_created`…),
  `EDA.Webhook.type` (`:incoming`, `:channel_follower`, `:application`), `EDA.Activity` `type`
  (`:playing`, `:streaming`, `:listening`, `:watching`, `:custom`, `:competing`) and
  `status_display_type`, `EDA.PermissionOverwrite.type` (`:role`, `:member`),
  `EDA.Poll.layout_type` (`:default`), `EDA.ScheduledEvent` `privacy_level`, `status` and
  `entity_type`, `EDA.StageInstance.privacy_level`, and on `EDA.Guild` `verification_level`,
  `default_message_notifications`, `explicit_content_filter`, `mfa_level`, `nsfw_level` and
  `premium_tier` (`:none`, `:tier_1`…). The calls that send them — creating a channel or a thread,
  editing a permission overwrite, modifying a guild, creating or modifying a scheduled event,
  building a poll — take the atom or the integer, and refuse an atom Discord does not have, naming
  the ones it does.

- **A channel's `type` is an atom**, Discord's name in lowercase: `:guild_text`, `:dm`,
  `:guild_voice`, `:group_dm`, `:guild_category`, `:guild_announcement`, `:announcement_thread`,
  `:public_thread`, `:private_thread`, `:guild_stage_voice`, `:guild_directory` (newly known),
  `:guild_forum`, `:guild_media`. A type Discord adds later stays the integer.
  `EDA.Channel.type_value/1` and `type_name/1` convert; the `type_*/0` functions still return the
  integers. So do a voice channel's `video_quality_mode` (`:auto`, `:full`) and a forum's
  `default_sort_order` (`:latest_activity`, `:creation_date`) and `default_forum_layout`
  (`:not_set`, `:list_view`, `:gallery_view`).

- **Every date is a `DateTime`**, where most were the string Discord sent and a few an integer:
  `EDA.Message` `timestamp` and `edited_timestamp`; `EDA.Member` `joined_at`, `premium_since` and
  `communication_disabled_until`; `EDA.Guild.joined_at`; `EDA.Channel.last_pin_timestamp`;
  `EDA.Channel.Thread` `archive_timestamp` and `create_timestamp`;
  `EDA.Channel.ThreadMember.join_timestamp`; `EDA.VoiceState.request_to_speak_timestamp`;
  `EDA.Invite` `expires_at` and `created_at`; `EDA.Poll.expiry`; `EDA.ScheduledEvent`
  `scheduled_start_time` and `scheduled_end_time`; `EDA.Subscription` `current_period_start`,
  `current_period_end` and `canceled_at`; `EDA.Integration.synced_at`; `EDA.GuildTemplate`
  `created_at` and `updated_at`; `EDA.Attachment.clip_created_at`; `EDA.Activity.created_at` (was
  Unix milliseconds); `TYPING_START`'s `timestamp` (was Unix seconds); `CHANNEL_PINS_UPDATE`'s
  `last_pin_timestamp` and `THREAD_MEMBER_UPDATE`'s `join_timestamp`. Compare them with
  `DateTime.compare/2`, or show them with `EDA.Mention.timestamp/2`.

- **`GUILD_SCHEDULED_EVENT_CREATE`, `_UPDATE` and `_DELETE` deliver an `EDA.ScheduledEvent`**,
  instead of structs of their own that dropped the cover image and the recurrence rule and kept
  the creator as a raw map; it is an `EDA.User` now.

- **`GUILD_MEMBER_ADD` and `GUILD_MEMBER_UPDATE` deliver an `EDA.Member`**, with `guild_id` set,
  instead of structs of their own that dropped `flags`, `premium_since` (on a join), the member's
  decoration and nameplate. `EDA.Member.flags/1`, `EDA.Permission.for_member/2` and the rest take
  the event as is.

- **`GUILD_CREATE`, `GUILD_AVAILABLE` and `GUILD_UPDATE` deliver an `EDA.Guild`**, instead of
  structs of their own. The lists only `GUILD_CREATE` carries — `channels`, `threads`, `members`,
  `voice_states`, `presences`, `stage_instances`, `guild_scheduled_events`,
  `soundboard_sounds` — are typed (`EDA.Channel`, `EDA.Member`, `EDA.VoiceState`,
  `EDA.SoundboardSound`) and describe that moment only: they are `nil` on a guild from
  `EDA.Guild.fetch/1` or the REST API. Read the current state from `EDA.Cache.members/1`,
  `EDA.Cache.channels_for_guild/1` and the like.
- **The guild cache holds the guild object alone**, without those lists and without the roles,
  which each have a cache of their own. `EDA.Guild.fetch/1` fills `roles` from the role cache.

- **`INVITE_CREATE` delivers an `EDA.Invite`**, instead of a struct of its own. `EDA.Invite` gains
  `role_ids`, filled from the event's `role_ids` or from the partial roles the REST routes send.

- **`EDA.Channel` groups what only one kind of channel has** into `thread`, `forum`, `voice` and
  `dm`, each `nil` on another kind:
  - `channel.thread` — `EDA.Channel.Thread`, with `thread_metadata` flattened into it
    (`channel.thread.archived`, `.locked`, `.invitable`, `.auto_archive_duration`…), the counters,
    `applied_tags`, `newly_created` and the bot's membership as an `EDA.Channel.ThreadMember`;
  - `channel.forum` — `EDA.Channel.Forum`: `available_tags`, `default_reaction_emoji`,
    `default_sort_order`, `default_forum_layout`;
  - `channel.voice` — `EDA.Channel.Voice`: `bitrate`, `user_limit`, `rtc_region`,
    `video_quality_mode`, `status`;
  - `channel.dm` — `EDA.Channel.DM`: `recipients` (as `EDA.User` structs), `icon`,
    `application_id`, `managed`.

  So `channel.bitrate` becomes `channel.voice.bitrate`, `channel.available_tags` becomes
  `channel.forum.available_tags` and `channel.thread_metadata["archived"]` becomes
  `channel.thread.archived`. Keeping every field flat would have taken the struct past 31 fields,
  where a map leaves its compact form — about 3.5 times the memory for the struct, on the entity
  the cache holds by the thousand. Measured on 372 real channels, a channel is now smaller than
  before while holding more.
- **`CHANNEL_CREATE`, `CHANNEL_UPDATE`, `CHANNEL_DELETE`, `THREAD_CREATE`, `THREAD_UPDATE` and
  `THREAD_DELETE` deliver an `EDA.Channel`**, instead of structs of their own that kept 10 or 12
  fields. `THREAD_LIST_SYNC` carries `EDA.Channel` and `EDA.Channel.ThreadMember` structs, and
  `THREAD_MEMBERS_UPDATE` its added members as `EDA.Channel.ThreadMember`.

- **`MESSAGE_CREATE` and `MESSAGE_UPDATE` deliver an `EDA.Message`**, instead of a struct of their
  own that copied part of it: match `{:MESSAGE_CREATE, %EDA.Message{} = msg}`. The message received
  can now be passed straight to `EDA.Message.reply/2`, `edit/2`, `react/2` and `delete/2`, which
  used to refuse it with a `FunctionClauseError`. `EDA.Event.MessageCreate` and `MessageUpdate`
  remain as the parsers.

- `EDA.Event.Raw`, the fallback for a gateway event EDA does not type yet, keeps its `data` as
  Discord sent it, with string keys, instead of converting the top-level keys to atoms: read
  `raw.data["guild_id"]` rather than `raw.data.guild_id`. Converting created an atom for every key
  of every unknown payload, and atoms are never freed. The event still reaches the consumer under
  its own name, so a new event can be matched before EDA types it.

- `EDA.API.Invite.create/2` sends up to 1000 `target_users` as the JSON array Discord now
  accepts, so the list is in force when the call returns, instead of uploading a CSV and leaving
  the caller to poll. A longer list, or a CSV binary, still uploads. Two findings from that
  route, both documented: an invite created this way carries **no** `flags`, so
  `EDA.Invite.has_target_users?/1` answers `false` although the invite is restricted; and there
  is no job to poll, so `target_users_job_status/1` answers error `10124`.
- `avatar_decoration_data` and `collectibles` on a user or member are `EDA.User.AvatarDecoration`
  and `EDA.User.Collectibles` (holding an `EDA.User.Nameplate`) instead of raw maps. The
  decoration carries `expires_at`, which Discord sends but does not document. Code that read them
  with string keys keeps working, as on every other nested object.

### Fixed

- A message activity of type 6, `STREAM_REQUEST`, was left as the integer; it is
  `:stream_request`.

- `EDA.User.avatar_url/1` returned `.png` for every avatar, animated ones included, and neither
  it, `EDA.Guild.icon_url/1` nor `EDA.Emoji.image_url/1` took a size. All three now take options:
  `:format` (`:png`, `:jpg`, `:webp`, `:gif`), `:size` (a power of two from 16 to 4096) and
  `animated: false`. An animated image defaults to GIF, and `:webp` keeps it animated, as Discord
  recommends. Asking for the GIF of a still image raises, since the CDN answers 415, as does an
  invalid size or format. Every URL was checked against the CDN.

- `EDA.API.Guild.audit_log/2` returned the entries with their `users` and `webhooks` only. It
  now also returns the `application_commands`, `auto_moderation_rules`,
  `guild_scheduled_events`, `integrations` and `threads` Discord sends alongside, so an entry's
  target can be named without another request.

- `INTERACTION_CREATE` dropped what a user-installed command needs to know where it runs and who
  installed it. It now keeps `context` (`:guild`, `:bot_dm`, `:private_channel`),
  `authorizing_integration_owners` (`%{guild_install: _, user_install: _}`),
  `attachment_size_limit`, `version`, and the partial `guild` and `channel` Discord attaches, as
  `EDA.Guild` and `EDA.Channel` — the only channel data such a command gets in a guild the bot is
  not in. `entitlements` are `EDA.Entitlement` structs. The partial guild's `locale` lands in
  `preferred_locale`.

- More fields Discord documents were dropped: a role's `flags` (selectable in an onboarding
  prompt); a reaction's `count_details` (`%{burst: _, normal: _}`), `me_burst` and
  `burst_colors`, without which a super reaction looked like a normal one; a clip attachment's
  `clip_participants` (as `EDA.User` structs), `clip_created_at` and `application`; an
  activity's `status_display_type`, `details_url` and `state_url`; a follower webhook's
  `source_guild` and `source_channel`, and a webhook's `url`.

- `EDA.Guild` kept 12 of the guild object's fields. It now keeps all of them: `features`,
  `premium_tier`, `premium_subscription_count`, `premium_progress_bar_enabled`, `banner`,
  `splash`, `discovery_splash`, `icon_hash`, `description`, `vanity_url_code`,
  `preferred_locale`, the verification, notification, content filter, MFA and NSFW levels, the
  AFK channel and timeout, the widget settings, the system, rules, public updates and safety
  alerts channels with the system channel's flags, `application_id`, the member, presence and
  video limits, the approximate counts, `welcome_screen`, `incidents_data`, `owner`,
  `permissions`, `emojis` and `stickers`.
- `EDA.Guild.fetch/1` returned channels, members and roles frozen when the bot joined the guild:
  the cache stored the whole `GUILD_CREATE` and nothing updated the copy. Every member was also
  held twice, the second copy outside the member cache's `max_size`.
- The active threads `GUILD_CREATE` carries were thrown away; they now go to the channel cache.
  `GUILD_EMOJIS_UPDATE` and `GUILD_STICKERS_UPDATE` now update the guild's emojis and stickers
  in the cache.

- `INVITE_CREATE` dropped `expires_at`, `created_at`, `target_type`, `target_user`,
  `target_application` and the roles the invite grants, all of which a bot tracking its invites
  needs.

- A change to a forum's tags, a channel's flags or a voice channel's region was invisible in
  `CHANNEL_UPDATE`, whose struct dropped them. `EDA.Channel` also gained what it never kept:
  `rtc_region`, `video_quality_mode`, a DM's `recipients`, `icon`, `application_id` and `managed`,
  a thread's `newly_created` and the bot's thread membership.

- A message received through the gateway lost its poll and its reactions — a poll arrived without
  its poll. It now carries every field Discord documents: `webhook_id` (present on 23 % of the
  messages sampled on a real bot; the one way to tell a webhook's message apart), `flags`,
  `application_id`, `interaction_metadata` (who ran the command a reply answers),
  `message_snapshots` (the content of a forward), `thread` (as an `EDA.Channel`),
  `mention_channels`, `nonce`, `position`, `activity`, `application`, `call`,
  `role_subscription_data`, `resolved`, `shared_client_theme` and `channel_type`. Only the
  deprecated `interaction` is left out.

- `EDA.Emoji`, `EDA.Sticker`, `EDA.Sticker.Pack`, `EDA.AutoMod` and its action and metadata
  structs, `EDA.GuildTemplate` and its source guild did not implement the access every other
  struct offers, so `reaction.emoji["name"]` or `get_in(event, ["emoji", "name"])` raised
  `UndefinedFunctionError` — on the emoji of every reaction event. A test now walks every struct
  built from Discord data, so one added without it fails.
- Reading a struct field by string key (`msg["content"]`) no longer converts the key to an atom
  on every read: it is matched against the struct's own fields, about 2.5 times faster, now
  quicker than a lookup in a raw map. Writing through that access (`put_in/2`, `pop_in/1`) can no
  longer add a key the struct does not have or remove one it has: an unknown key raises
  `KeyError`, and popping a field resets it to `nil`.

## [0.5.0-beta.2] - 2026-09-22

The second beta of 0.5 fixes what live testing of the first found in voice. Received audio that
failed DAVE decryption reached the consumer still encrypted, and a session that stopped
decrypting never recovered; two processes on the same token took the voice connection from each
other in a loop. Nothing breaks from beta.1.

### Installation

```elixir
def deps do
  [
    {:eda, "~> 0.5.0-beta.2"}
  ]
end
```

A requirement of `"~> 0.5.0-beta.1"` already accepts this beta: `mix deps.update eda` fetches it.

### Added

- `EDA.Permission.for_member/2` computes a member's guild permissions from an `EDA.Member` or a
  raw member map, such as the one an interaction carries. Unlike `in_guild/2`, the member need not
  be cached, which without the `GUILD_MEMBERS` intent most are not.

### Fixed

- `SHARD_READY` and `ALL_SHARDS_READY` report the number of guilds loaded in `guild_count`, and
  the startup log line with them. They always said 0: the count was read once every guild had
  arrived, from the counter of guilds still pending. A shard that times out counts the guilds
  that did arrive. When the bot is declared ready is unchanged — it already waited for every
  guild.
- A received voice frame that failed DAVE decryption was dispatched as `VOICE_AUDIO` anyway,
  still encrypted, and never counted as a failure: the check for passthrough read the NIF's
  `{:ok, false}` as true. Such frames are now dropped, and `[:eda, :voice, :dave,
  :frame_decrypt_error]` fires for them as documented.
- A DAVE session that stops decrypting now recovers by itself. After 36 frames in a row fail, the
  last transition is reported to Discord as invalid and the session re-initialised, so the bot is
  removed from the group and added again — measured at under a second in a live channel. It used
  to stay broken until the bot left the channel. Failures while a transition is pending are
  expected and not counted.
- A received RTP packet carrying only padding — clients send them to probe bandwidth — was
  dispatched as `VOICE_AUDIO` with empty `opus`. It is now ignored. Under DAVE, these packets
  were every decryption failure seen in a live channel — 10 in 40 s of speech, against none among
  the 920 frames of audio and silence.
- Two processes running on the same token — a deploy overlapping the old instance — took the
  voice connection of a guild from each other in a loop once both had joined: each one reacted to
  the other's voice state as if it were its own, restarted its session, got a `4006`, and rejoined.
  Measured live: 16 restarts on each side in 30 s. The bot's voice state carries the gateway
  session that joined, so a process now recognises another's, and the one that joined last keeps
  the connection; the other stops its session, without disconnecting the new holder, and logs a
  warning.

## [0.5.0-beta.1] - 2026-09-21

The first beta of 0.5: a large minor release. Voice needs neither Rust nor configuration any
more, every gateway event Discord documents is a typed struct, and EDA now covers every route of
Discord's reference that a bot token can use — modal components, the soundboard, onboarding, the
bot's own application, message search, guild administration and more. One change is breaking:
an option a route does not define now raises instead of warning.

### Installation

```elixir
def deps do
  [
    {:eda, "~> 0.5.0-beta.1"}
  ]
end
```

Hex installs a pre-release only for a requirement that names one, as above.

### Upgrading from 0.4

- **An unknown option now raises `ArgumentError`** and nothing is sent. 0.4.1 already logged
  `unknown option` for each such call: a project that saw none of those warnings is unaffected.
- **DAVE is on whenever its NIF is loaded**, and the NIF is now downloaded precompiled. Remove
  `config :eda, dave: true` if you like, and `{:rustler, ...}` if you added it only for voice.
  `dave: false` still turns DAVE off.
- **`EDA.File`'s `spoiler: true` keeps the filename** instead of prefixing `SPOILER_`; code that
  read the prefix back should use `EDA.Attachment.spoiler?/1`.
- **`EDA.Interaction.resolved_channel/2` and `resolved_channels/1` return `%EDA.Channel{}`
  structs.** Their fields stay reachable with string keys (`channel["name"]`).

### Added

- **Attachment flags** — `EDA.Attachment.spoiler?/1`, `clip?/1`, `thumbnail?/1`, `remix?/1`,
  `animated?/1`, plus `has_flag?/2`, `flag_list/1` and the five `flag_*/0` constants. `spoiler?/1`
  reads the flag Discord reports rather than guessing from a `SPOILER_` filename prefix
- **`EDA.Attachment.keep/2`** and the `:attachments` option on message create and edit — the array
  Discord uses to decide which attachments a message keeps. `keep/2` also carries the two fields an
  edit may change on an attachment that already exists, so a file can be blurred, un-blurred or
  re-captioned without re-uploading it
- `EDA.Message.edit/2` accepts a keyword list, including `attachments: :keep` — shorthand for the
  attachments the struct already holds, which is what stops an upload from wiping them
- `EDA.Attachment` gained the `title`, `flags`, `placeholder` and `placeholder_version` fields
- JSON error codes `160009` (cannot reference without read message history), `160010` (NSFW channel
  message reference) and `160014` (cannot forward a message whose content you cannot read)
- **`EDA.Cache.Adapter`** — the cache storage backend is now a behaviour with swappable
  implementations, configured with `config :eda, cache_adapter: ...`. Ships
  `EDA.Cache.Adapter.ETS` (the default, unchanged behaviour) and `EDA.Cache.Adapter.NoOp`
  (stores nothing — useful for memory-constrained or stateless bots)
- **`EDA.Cache.Adapter.Mnesia`** — a cluster-wide cache backend. A bot running several nodes
  gets one view of the cache: an entity seen by one node's shards is readable from every other
  node, and a restarting node rejoins a populated cache instead of a cold one. Configurable
  through `config :eda, cache_mnesia: [copies: ..., nodes: ..., wait_timeout: ...]`. `:mnesia`
  stays out of EDA's `:extra_applications` on purpose, so bots that never select this adapter
  never start it
- Admission policy, size limits, eviction and telemetry now live **above** the adapter rather
  than inside it, so a third-party backend inherits all four for free — a backend only has to
  answer where an entity lives
- **`EDA.API.Message.search/2`** and **`EDA.Message.search/2`** — search a guild's message
  history (`GET /guilds/{id}/messages/search`). Every documented filter is supported, including
  the multi-valued ones, and options take atoms (`has: [:image]`, `sort_by: :relevance`) rather
  than Discord's strings
- `EDA.Message.search/2` flattens what the endpoint returns: `messages` is a list of *context
  groups*, not of messages, with the match marked `"hit" => true`. It answers with `:results`
  (the matches, as structs), `:groups` (each match with its neighbours), `:total_results` and
  `:indexing?`
- An option `search/2` does not define is refused rather than forwarded, since Discord ignores
  a query parameter it does not recognise — a typo would otherwise return the guild's whole
  history while looking like a filtered search
- The filter limits Discord documents are checked before the request — `:limit` 1–25, `:offset`
  ≤ 9975, `:content` ≤ 1024 characters, 500 channels, 100 authors — with a message naming the
  option, rather than an opaque `50035`
- JSON error code `110000` (search index not yet available)
- **Invite target users** — an invite can be restricted to a named list of people.
  `EDA.API.Invite.target_users/1`, `update_target_users/2` and `target_users_job_status/1`,
  plus `:target_users` on `create/2`. Discord carries the list as a CSV file uploaded as
  `multipart/form-data`; EDA takes and returns plain lists of user ids and handles the file on
  both sides. The upload is asynchronous, so the job status names its states — `:processing`,
  `:completed`, `:failed`
- **`EDA.API.Invite.get/2`** — `GET /invites/{code}`, with `:with_counts` and
  `:guild_scheduled_event_id`. It had no wrapper at all
- `:role_ids` on `EDA.API.Invite.create/2` — roles granted to whoever accepts the invite
  (requires `MANAGE_ROLES`), and `:reason` on `create/2` and `delete/2`
- **`EDA.Invite` entity functions** — `fetch_invite/2`, `create/2`, `delete/2`,
  `target_users/1`, `set_target_users/2`, all returning structs
- `EDA.Invite` gained `type`, `flags`, `roles`, `expires_at`, `created_at`, `guild`, `channel`,
  `target_application`, `guild_scheduled_event` and the two approximate counts, plus
  `type/1`, `target_type/1`, `guest_invite?/1`, `has_target_users?/1`, `permanent?/1` and
  `url/1`. `guild_id` and `channel_id` are derived from the nested objects when Discord sends
  the REST shape rather than the gateway one
- An option `create/2` or `get/2` does not define is refused rather than forwarded: Discord
  ignores a body field or query parameter it does not recognise, so `max_ages:` would quietly
  produce the default 24-hour invite while looking like it asked for an hour
- `EDA.HTTP.Multipart.encode_named/2`, and a matching sender in the internal HTTP client, for
  endpoints wanting a file under a name of its own rather than the `files[n]` attachment
  convention
- **`EDA.API.Member.modify_me/2`** and **`EDA.Member.modify_me/2`** — the bot's per-guild profile
  (`PATCH /guilds/{id}/members/@me`). Sets `nick`, `avatar`, `banner` and `bio` for one guild,
  overriding the account-wide identity there. Only `:nick` needs a permission
  (`CHANGE_NICKNAME`); the appearance fields need none
- **`EDA.ImageData`** — builds the base64 data URIs Discord calls *image data*, for every endpoint
  that takes an avatar, banner, icon or emoji rather than a file upload. The media type is read
  from the image's magic number instead of its extension, and a format Discord does not accept —
  WebP above all — is refused locally with a readable message instead of producing an opaque API
  error
- `:avatar` and `:banner` accept a path, raw image bytes or a ready-made data URI on
  `EDA.API.Member.modify_me/2` and `EDA.API.User.modify_me/1`; `nil` clears the field
- `EDA.Member` gained the `banner` and `bio` fields
- `modify_me/2` refuses an option it does not define instead of dropping it — `nickname:`
  previously answered `{:ok, member}` with nothing changed — and enforces the 32-character
  nickname limit Discord enforces. No bio limit is imposed, because Discord imposes none
- **Permissions straight off an interaction** — a resolved channel carries two bitsets Discord
  computed for you: `app_permissions` for the bot and `permissions` for the invoking user.
  `EDA.Interaction.app_permissions/1,2`, `user_permissions/1,2`, `can?/2,3`, `user_can?/2,3` and
  `permission_list/1,2` read them, so "may I post in the channel they picked?" needs no REST
  call and no permission arithmetic
- `user_permissions/1` and `user_can?/2` answer the same question for the **invoking user** in
  the channel the interaction came from, which Discord ships on the interaction's `member`
- An absent bitset is `nil`, never `0` — being told nothing is not the same as being denied
  everything, and the documentation says when a resolved channel's `app_permissions` is absent
- `EDA.Member` gained `permissions`, the precomputed bitset Discord sends on an interaction's
  member and which `from_raw/1` was dropping
- `EDA.Interaction.resolved_channel/2` and `resolved_channels/1` return `%EDA.Channel{}` structs
  instead of raw maps
- `EDA.Channel` gained `permissions`, `app_permissions` and `last_pin_timestamp` — fields Discord
  sends only on the partial channel objects inside an interaction
- **`EDA.Subscription`** — the monetization endpoints returned raw maps with a status integer
  and nothing to interpret it. `status/1` names it `:active`, `:inactive` or `:ending`, with
  `status_value/1`, `renewing?/1`, `canceled?/1` and `changing_plan?/1` over it, plus
  `fetch_subscription/2` and `list/2` returning structs. Discord **renumbered** this enum on
  2026-06-16 — `INACTIVE` and `ENDING` swapped values — so code comparing the raw integer kept
  running and started meaning the opposite; the moduledoc says so
- **`EDA.User.premium_type/1`** and `nitro?/1` — names the Nitro tier. The field needs the
  `identify.premium` OAuth2 scope, so it is absent from every user a bot sees; `nil` means
  *not known* and is deliberately a different answer from `:none`
- `EDA.User` now keeps `premium_type`, `mfa_enabled`, `locale`, `verified`, `email`,
  `avatar_decoration_data` and `collectibles`, which `from_raw/1` was dropping. On a real guild
  the last two are set on 129 and 111 of 573 users
- **`:file_types` on `EDA.Command.Option.attachment/3`** — up to ten filters narrowing the file
  picker Discord shows the user, as `:image`, `:video`, `:audio` or a dot-prefixed extension
- **`EDA.FileType`** — the rules behind those filters, in a module of its own so the File Upload
  component can share them. `normalize!/1` validates, `expand/1` resolves the group names to
  concrete extensions, `matches?/2` re-applies the filter to a filename, and `equivalent?/2`
  compares two filter lists ignoring order
- The filters are validated before Discord sees them: `"pdf"` written without its dot, a group
  name that does not exist, and an eleventh filter are all refused with a message naming the
  fix. Discord takes the first two without complaint and then shows the user nothing
- **Modal components** — every field Discord now offers in a modal, in `EDA.Modal`: `label/3`
  (type 18) carries a field's label and description; inside it go `text_field/3`, the select
  menus of `EDA.Component`, `file_upload/2` (19), `radio_group/3` (21), `checkbox_group/3` (22)
  and `checkbox/2` (23), with `choice/3` for the options of the two groups.
  `EDA.Component.text_display/1` can sit between fields. Discord's limits — lengths, option
  counts, 0–10 files, one default per radio group, `min_values: 0` only when optional, no
  disabled component, what may go in a label and what must — are checked when the modal is
  built, with a message naming the fix instead of an opaque `50035`
- `EDA.Modal.modal/3` takes a list of components. The positional form and `text_input/4` with
  its action rows keep working; Discord still accepts them but no longer recommends them
- `EDA.Modal.get_values/1` reads label-based submissions and returns each value in the shape of
  its component: a string for a text field, a list for a select, checkbox group or file upload,
  a string or `nil` for a radio group, a boolean for a checkbox
- `EDA.Modal.get_attachments/2` — the files a file upload received, as `EDA.Attachment` structs
- `:required` on every select menu (modal only), and `:default_values` on user, role,
  mentionable and channel selects, to prefill them. A mentionable select takes `{:user, id}` or
  `{:role, id}`, and defaults beyond `:max_values` — which Discord sets to 1 — are refused
- **Soundboard** — `EDA.API.Soundboard` covers all seven routes: `default_sounds/0`, `list/1`,
  `get/2`, `create/2`, `modify/3`, `delete/3`, and `send_sound/3`, which plays a sound into a voice
  channel the bot has joined. `EDA.SoundboardSound` is the struct, with `list/1`,
  `default_sounds/0`, `fetch_sound/2`, `play/3` — which supplies the source guild of a guild's
  sound itself — `url/1` and `default?/1`
- **`EDA.SoundData`** — builds the MP3 or Ogg data URI a sound is uploaded as. `:sound` on
  `create/2` takes a path, raw bytes or a URI; the format is read from the audio's header, not
  its extension, and a sound over Discord's 512 KiB is refused before it is sent
- **Soundboard events** — `GUILD_SOUNDBOARD_SOUND_CREATE`, `_UPDATE`, `_DELETE`,
  `GUILD_SOUNDBOARD_SOUNDS_UPDATE` and `SOUNDBOARD_SOUNDS`, as typed structs holding
  `EDA.SoundboardSound`s. They fell through to `EDA.Event.Raw` before
- **`EDA.SoundboardSound.request/1`** — asks the gateway for several guilds' sounds at once
  (opcode 31), one request per shard, answered by a `SOUNDBOARD_SOUNDS` event per guild
- **`VOICE_CHANNEL_EFFECT_SEND`** — `EDA.Event.VoiceChannelEffectSend`, sent when someone in the
  bot's voice channel plays a sound or sends an emoji reaction. `soundboard?/1` tells the two
  apart, and the animation type is `:premium` or `:basic`
- **The bot's own application** — `EDA.API.Application.me/0` and `modify_me/1`
  (`GET` / `PATCH /applications/@me`), `activity_instance/1`, and the `EDA.App` struct with
  `me/0`, `modify/1`, `flags/1`, `has_flag?/2`, `integration_types/1`, `icon_url/2` and
  `cover_image_url/2`. It is `EDA.App` because `EDA.Application` is EDA's OTP application
- `EDA.App` reads `flags_new` when Discord sends it: `flags` stops at 31 bits and any newer flag
  appears only in the string, so code reading `flags` alone would miss it without a sound
- `modify_me/1` takes friendly forms and translates them: flags as atoms, permissions as
  `EDA.Permission` atoms, `integration_types_config` keyed by `:guild_install` /
  `:user_install`, `event_webhooks_status` as `:enabled` / `:disabled`, and `:icon` /
  `:cover_image` as a path or bytes through `EDA.ImageData`. What Discord would refuse is refused
  before sending: a flag other than the three limited intents, more than 5 tags or one over 20
  characters
- **Guild onboarding** — `EDA.API.Guild.onboarding/1` and `modify_onboarding/2`
  (`GET` / `PUT /guilds/{id}/onboarding`), and `EDA.Onboarding` with its `Prompt` and `Option`
  structs: `fetch/1`, `save/2`, `prompt/3`, `option/2`, `add_prompt/2` and `remove_prompt/2`
- The round trip is safe. Discord returns an option's emoji as an `emoji` object but only accepts
  `emoji_id` / `emoji_name` / `emoji_animated`, so saving an onboarding exactly as it was read
  cleared every emoji — confirmed against the live API. Every request, from structs or from raw
  maps, now sends the flat fields
- New prompts and options get a placeholder id: Discord refuses a prompt without one, then
  replaces it with its own on save
- **Every gateway event Discord documents is now a typed struct.** Fourteen fell through to
  `EDA.Event.Raw`: `USER_UPDATE`; `ENTITLEMENT_CREATE` / `_UPDATE` / `_DELETE` and
  `SUBSCRIPTION_CREATE` / `_UPDATE` / `_DELETE`, the gateway half of monetization EDA already
  covered over REST; `INTEGRATION_CREATE` / `_UPDATE` / `_DELETE` and `GUILD_INTEGRATIONS_UPDATE`;
  `APPLICATION_COMMAND_PERMISSIONS_UPDATE`; `CHANNEL_INFO` and `VOICE_CHANNEL_START_TIME_UPDATE`
- New structs behind them: **`EDA.Entitlement`** (with `active?/2`, since an expired entitlement is
  not deleted), **`EDA.Integration`** and **`EDA.Command.Permissions`** (recognising the
  `@everyone` and all-channels constants)
- **`EDA.Channel.request_info/2`** — opcode 43, Request Channel Info: voice channel statuses and
  session start times, which are not on the channel object, answered by `CHANNEL_INFO`. Start
  times are `DateTime`s; the live gateway sends them as strings though the reference says integer,
  and both are read
- Fifteen audit log action types: soundboard (130–132), automod quarantine (146), creator
  monetization (150–151), onboarding (163–167), home settings (190–191), voice channel status
  (192–193)
- **`EDA.Error.not_found?/1`** — a 404, or one of Discord's *Unknown …* codes (10001–10999)
- **`EDA.Member.top_role/2`** and **`top_role_position/2`** — the member's highest role in a
  guild, ordered as Discord orders the hierarchy
- **`EDA.Cache.get_role/2`** and `EDA.Cache.Role.get/2` — a role looked up by guild and role id
  in one read, `nil` for a role of another guild
- **The bot's guilds** — `EDA.API.User.guilds/1` (`GET /users/@me/guilds`, with `:shard`, which
  Discord requires under large bot sharding since September 2026, and `:with_counts`),
  `stream_guilds/1` past the 200-per-call limit, and **leaving a guild** with
  `EDA.API.User.leave_guild/1` / `EDA.Guild.leave/1`
- **Announcements** — `EDA.API.Message.crosspost/2` / `EDA.Message.crosspost/1` publish a message
  to the channels following it; `EDA.API.Channel.follow/3` / `EDA.Channel.follow/3` follow an
  announcement channel into another
- **Archived threads** — `EDA.API.Thread.list_public_archived/2`, `list_private_archived/2`,
  `list_joined_private_archived/2`, and `stream_archived/3` paging on each kind's own cursor. A
  `DateTime` is accepted for `:before`
- **Application emojis** — `EDA.API.Emoji.list_application/0`, `get_application/1`,
  `create_application/2` (image as a path, bytes or data URI), `modify_application/2` and
  `delete_application/1`
- **`EDA.API.Voice`** — `regions/0`, and Stage voice states: `voice_state/2` for the bot (`:me`)
  or a user, and `modify_voice_state/3` to move someone on or off stage, or raise the bot's hand
- **Guild administration** in `EDA.API.Guild`: `integrations/1` and `delete_integration/3`;
  `welcome_screen/1` and `modify_welcome_screen/2`; `preview/1`; `vanity_url/1` (the only way to
  the vanity invite's use count); `voice_regions/1`; `widget_settings/1`, `modify_widget/2`,
  `widget/1` and `widget_image_url/2`; and `modify_incident_actions/2`, which pauses invites or
  DMs during a raid and refuses a pause over Discord's 24 hours before sending
- **Command permissions** — `EDA.API.Command.permissions/1,2` read who may use the app's commands
  in a guild. Writing them needs a user's OAuth2 token, not a bot's
- **Role connection metadata** — `EDA.API.Application.role_connection_metadata/0` and
  `update_role_connection_metadata/1`, with named types and Discord's limits checked: 5 records,
  keys of `a-z`, `0-9` and `_`

### Changed

- **`EDA.File`'s `:spoiler` option no longer renames the file.** It sets the attachment request's
  `is_spoiler` field instead, so the name you chose is the name Discord shows — previously every
  spoiler arrived as `SPOILER_holiday.png`. `EDA.File.effective_name/1` returns the name unchanged;
  a prefix you write yourself still works
- `EDA.HTTP.Multipart.encode/2` keeps an `attachments` array already present in the payload and
  indexes uploads after it, instead of replacing it
- `EDA.API.Message.forward/3` documents that Discord requires read access to the source message's
  content, and which error says it was refused
- **Breaking: an option a route does not define now raises `ArgumentError`, and nothing is
  sent.** 0.4.1 logged a warning and sent the request unchanged, as announced there. Discord
  ignores a field or query parameter it does not recognise, so a misspelt option never failed —
  it silently did nothing, or worse: `limit` mistyped on a member listing returned one member,
  `user_id` mistyped on an entitlement listing returned everybody's, and `day: 30` on a prune kicked
  on the default seven days. The error names the function and the accepted keys. A project that
  saw no `unknown option` warning on 0.4.1 is unaffected.
- **Voice works without Rust and without configuration.** The DAVE NIF is now downloaded precompiled
  when EDA compiles — Linux (x86-64, ARM64, ARMv7, RISC-V; glibc and musl), macOS, Windows and
  FreeBSD — and checked against checksums shipped in the package. A project that added
  `{:rustler, ...}` for voice can drop it. Building from source remains available with
  `config :rustler_precompiled, :force_build, eda: true`. If the NIF can be neither downloaded nor
  built, EDA still compiles, with a warning, and only voice is affected.
- **DAVE is on by default whenever the NIF is loaded.** Discord refuses voice without it outside
  Stage channels, so `config :eda, dave: true` is no longer needed; `dave: false` turns it off.
- The 4017 refusal now says why DAVE was not offered: turned off by `dave: false`, or the NIF not
  loaded.

### Fixed

- A string-keyed map — a decoded JSON body, such as `EDA.API.User.modify_me(%{"username" => "x"})`
  — no longer crashes the option check with an opaque "expected a keyword list" error. Every route
  validating a map body was affected since 0.4.1. A string key now counts as the atom of the same
  name.
- DAVE transitions are followed as the protocol specifies. A downgrade to protocol 0 is
  acknowledged — before, it went unanswered and the transition stalled — and then sends media
  unencrypted, as Discord expects; an upgrade restores end-to-end encryption, including for playback
  already under way.
- A refused MLS commit now recovers the way a refused welcome does, by re-initialising and offering a
  new key package. Recovery happens once per failure, not once per message.
- Recovery and a new group (epoch 1) re-initialise the MLS session instead of resetting it. A reset
  left no pending group, so a session that then had to commit failed.
- Joining a call no longer logs `Welcome failed` as a warning. A welcome that arrives after the bot
  joined through its own commit is the expected outcome of a race at join, and is logged at debug.
- Opus silence frames are no longer counted as DAVE decryption errors.
- The internal query-string builder expands a list value into repeated keys
  (`channel_id=a&channel_id=b`), which is how Discord expresses a multi-valued filter.
  `URI.encode_query/1` raises on a list, so any endpoint needing one was unreachable
- **`EDA.Cache.me/0` follows `USER_UPDATE`.** Renaming the bot or changing its avatar left the
  cached bot user as it was at `READY` for the rest of the session
- **An interaction response with files lost its attachment metadata.** The `attachments` array
  went at the top of the callback payload, where Discord ignores it, instead of inside `data` —
  so file descriptions and spoilers were dropped. It now goes inside `data`
- **An interaction is never dropped when EDA is at `max_event_concurrency`.** Discord waits three
  seconds for an answer and does not redeliver, so a dropped `INTERACTION_CREATE` was a failure
  shown to the user. Interactions still count towards the limit; other events are still dropped
- **`EDA.Cache.fetch_member/2` caches what it fetches.** A member returned by REST carries no
  `guild_id`, so the REST fallback never stored it and every call went back to the API
- A consumer that `exit`s or `throw`s is logged with the event it was handling, like one that
  raises; only exceptions were caught

### Security

- The DAVE NIF now builds against `davey` 0.1.4 instead of 0.1.1. The older lock pulled in OpenMLS
  and cryptography crates with published advisories — GHSA-8x3w-qj7j-gqhf (high),
  GHSA-435g-fcv3-8j26 and GHSA-g433-pq76-6cmf — and 0.1.4 also brings the library's encryption in
  line with Discord's reference implementation. Only projects that compile the NIF (voice with
  `dave: true`) are affected; they pick this up on the next build.

### Documentation

- `EDA.User.display_name/1` explains why it does not read Discord's own `display_name` field:
  that field is null whenever the user has no global name — 46 of 573 users on a real guild —
  while this falls back to the username and always names somebody
- `EDA.FileType` states that this filter matches the **filename's extension** and never inspects
  the file, so it is not validation — Discord's own wording is that you remain responsible for
  checking the contents
- It also notes that Discord returns the filters in an order of its own, which makes a direct
  list comparison report "changed" forever when diffing a deployed command against its
  definition; `equivalent?/2` is the comparison to use
- `EDA.User.premium_type/1`: `0` is only meaningful for an app approved for `identify.premium`;
  Discord answers `0` to every other app, so `:none` there says nothing about the user's Nitro
- `EDA.Event.PresenceUpdate`: a custom status is omitted when the user's profile privacy hides it,
  so its absence does not mean there is none
- `EDA.API.Guild.prune/2` and `prune_count/2`: the `PRUNE_REQUIRES_ADMIN` guild feature makes them
  require `ADMINISTRATOR`

## [0.4.1] - 2026-09-21

A patch release: bug fixes and a dependency security update. Nothing is removed and no signature
changes. Upgrading needs no configuration change — though a project that added `{:rustler, ...}` only
because EDA would not compile without it can now drop it, and Rust with it.

### Installation

```elixir
def deps do
  [
    {:eda, "~> 0.4.1"}
  ]
end
```

### Security

- **httpoison 3 is accepted, and a fresh project resolves to it.** hackney 1.25.0, reached through
  httpoison 2, carries EEF-CVE-2026-47069, -47071 (high), -47075 and -47076, and the fixes exist only
  from hackney 4.0.1 — which httpoison 2 cannot use. EDA now requires `~> 2.0 or ~> 3.0`: a project
  held on httpoison 2 by another dependency still resolves, and everyone else gets hackney 4. Run
  `mix deps.update httpoison hackney` to move an existing lock

### Fixed

- **EDA compiled only if you added Rustler yourself.** `:rustler` is declared optional, but the DAVE
  NIF module called `use Rustler` unconditionally, so a project without it failed with *module Rustler
  is not loaded* — and adding it meant installing a Rust toolchain, whether or not the bot used voice.
  EDA now compiles without it, and the NIF functions raise `:nif_not_loaded` as documented
- **`dave: true` without the NIF no longer crashes the voice session.** EDA used to advertise DAVE to
  Discord and then call a stub that raises. It now advertises DAVE only when the NIF is loaded;
  otherwise it logs which dependency is missing. Discord has required DAVE for voice outside Stage
  channels since March 2026, so a bot that joins voice needs Rustler; the README's Voice section
  says what to add
- **Connecting to voice without DAVE is announced before Discord refuses it** — including in the
  default configuration, where `:dave` is not set and nothing used to be said. Once per VM, with a
  link to the README's Voice section
- **Close code 4017 names its cause.** Discord refuses a voice connection that does not offer DAVE
  with 4017 ("E2EE/DAVE protocol required"). EDA logged it as a generic disconnect; it now logs an
  error saying DAVE is required and how to enable it
- **Message options were silently dropped.** The keyword form of every message send —
  `EDA.API.Message.create/2`, `edit/3`, `reply/2`, `EDA.API.Webhook.execute/3`, `edit_message/4`,
  `EDA.API.Thread.create_post/3` — kept five keys and discarded the rest, and still answered
  `{:ok, message}`:
  - `allowed_mentions`, so `allowed_mentions: %{parse: []}` — the usual guard against user-supplied
    text pinging `@everyone` — did nothing, and the ping went out;
  - `flags`, so a silent message (`flags: 4096`) notified the channel;
  - `message_reference`, `tts`, `sticker_ids`, `nonce`, `enforce_nonce`;
  - on webhooks, `username`, `avatar_url`, `thread_name` and `applied_tags`
- **`v2: true` combines with an explicit `flags:`** instead of overwriting it
- **Webhook `thread_id`, `wait` and `with_components` travel in the URL**, where Discord reads them.
  `thread_id` used to be dropped, so a message meant for a thread went to the parent channel;
  `edit_message/4` accepts it too
- **`EDA.ready?/0` goes false while a shard is disconnected**, and true again once it resumes or
  completes a fresh READY. It used to stay true for good after the first READY, so a bot whose gateway
  had died — including for reasons that never reconnect, such as a revoked token — reported itself
  ready forever. `await_ready/1` now waits out an outage. REST keeps working meanwhile
- `EDA.API.Guild.prune/2`, `EDA.API.Webhook.create/2` and `modify/2`, `EDA.API.Thread.start/2` and
  `start_from_message/3`, `EDA.API.Channel.edit_permissions/3`, `EDA.API.User.modify_me/1` and
  `EDA.API.Entitlement.create_test/1` accept a keyword list; each raised inside the JSON encoder
- EDA's own code compiles without warnings on Elixir 1.20 — twenty `size(...)` patterns now pin their
  variables, ahead of that becoming an error, plus an unused `require` and an unreachable clause
- Starting without a token logs one line instead of a nine-line block and a second, redundant warning

### Deprecated

- **An option a route does not define now logs a warning, and will raise in 0.5.** Discord ignores a
  field or query parameter it does not recognise, so a misspelt option never failed — it silently did
  nothing: `limit` mistyped on a member listing returned one member instead of a thousand, `user_id`
  mistyped on an entitlement or subscription listing returned everybody's. Every route that takes
  options now names the ones Discord defines and warns about the rest, naming the function and the
  accepted keys. The request is still sent unchanged, so nothing that works today stops working

## [0.4.0] - 2026-09-19

### Installation

```elixir
def deps do
  [
    {:eda, "~> 0.4.0"}
  ]
end
```

### Added

- **Permission classification** — `EDA.Permission.channel_types/1`, `guild_only?/1`, `channel?/1`,
  `applies_to?/2` and `inapplicable/2`. The table is generated from Discord's own Bitwise Permission
  Flags reference rather than transcribed, so the twelve guild-level permissions and the text/voice/
  stage split come from the source. `inapplicable/2` lists the permissions in a bitset that have no
  effect in a given channel — Discord accepts `KICK_MEMBERS` in a channel overwrite and silently
  ignores it. JDA classifies permissions but offers no such check; Nostrum does neither
- **`EDA.Permission.explain/3`** — returns *how* a member's channel permissions were derived, not
  just the result: `:base` role permissions, the ordered `:steps` (each overwrite tier with the
  `:allow`/`:deny` it applied and the running result), which `:gates` fired, and `:denied_by` naming
  the gate that reduced the result to zero. Neither JDA nor Nostrum exposes the derivation
- **`EDA.Member.timed_out?/1`** and **`time_out_end/1`** — mirroring JDA's `isTimedOut()` /
  `getTimeOutEnd()`. Discord leaves `communication_disabled_until` populated after expiry, so
  `time_out_end/1` may return a past date while `timed_out?/1` answers `false`. Both accept a struct
  or a raw member map

- **`EDA.API.Role.member_counts/1`** — `GET /guilds/{id}/roles/member-counts`, returning a map of
  role ID to member count, mirroring discord.js's `guild.roles.fetchMemberCounts()`. The `@everyone`
  role is absent from the result (every member carries it), and the counts overlap — a member with
  three roles is counted in all three, so they sum to more than the guild's `member_count`.
  Unlike counting from `EDA.Cache.members/1`, it needs neither the privileged `:guild_members` intent
  nor a chunked cache, and it **includes roles with zero members**, which a cache-derived tally omits
  entirely

- **`EDA.Role.colors`** / **`EDA.Role.Colors`** — role colours, superseding the deprecated single
  `color` field. Three styles, matching JDA's `isDefault`/`isGradient`/`isHolographic` and
  discord.js's `RoleColors`: `style/1` returns `:default`, `:solid`, `:gradient` or `:holographic`,
  with `default?/1`, `solid?/1`, `gradient?/1` and `holographic?/1`. **`gradient?/1` is false for
  holographic roles** — Discord treats them as distinct styles. `EDA.Role.primary_color/1` prefers
  `colors.primary_color` and falls back to `color`
- **`primary_color: 0` means *no colour*, not black** — it is `:default`, as in JDA's `isDefault()`.
  Measured across 201 roles on 8 real guilds, 78 were in that state (39%), only 8 of them
  `@everyone`, so treating them as solid would mis-colour most of a guild's roles
- **Writing colours** — `EDA.API.Role.set_colors/4` and `EDA.Role.set_colors/4`, with the
  `EDA.Role.Colors.solid/1`, `gradient/2` and `holographic/0` constructors. Only the `colors` object
  is sent, never the deprecated `color`, matching discord.js. `EDA.Role.Colors` implements
  `Jason.Encoder` and `to_map/1` omits nil keys so a solid colour does not accidentally clear a
  gradient
- **Holographic is a constrained style**: sending `tertiary_color` makes Discord enforce
  `11127295 / 16759788 / 16761760`, so `holographic/0` takes no arguments and the three values are
  exposed as `holographic_primary/0`, `holographic_secondary/0` and `holographic_tertiary/0`
- **`EDA.Error.missing_guild_feature/0`** (670006) — returned as HTTP 403 when setting a gradient or
  holographic colour on an ineligible guild
- Observed on real guilds: every role carried all three keys, `primary_color` equalled the legacy
  `color` on all 57, and 7 used a gradient. `ENHANCED_ROLE_COLORS` appeared in the `features` array
  of **no** guild — not even the one with gradients already in place — so it cannot be used as a
  pre-check for either reading or writing. Writing on a boost-tier-0 guild returned 670006
- **`EDA.User.primary_guild`** / **`EDA.User.PrimaryGuild`** — the user's server tag
  (`identity_guild_id`, `identity_enabled`, `tag`, `badge`). `EDA.User.server_tag/1` returns the tag
  only when it is actually displayed, and `EDA.User.PrimaryGuild.badge_url/2` builds the CDN URL.
  `identity_enabled` is tri-state: `true` shown, `false` removed by the user, `nil` cleared by
  Discord — `displayed?/1` handles all three

- **`config :eda, capabilities:`** — opt into gateway capabilities before Discord makes them
  mandatory. Accepts a list of atoms, a single atom, or a raw bitfield so future capabilities need
  no library update. Unset by default, in which case no `capabilities` field is sent and IDENTIFY is
  unchanged. See `EDA.Gateway.Capabilities`
- **`:channel_obfuscation`** (`1 <<< 15`) — opts into Discord's redaction of channels the bot cannot
  see, which becomes **mandatory for every bot on 2026-11-16**. Obfuscated channels still arrive over
  the gateway but with `name` set to `"___hidden___"`, sensitive fields nulled, a single
  `@everyone` `VIEW_CHANNEL` deny in `permission_overwrites`, and `CHANNEL_OBFUSCATED` (`1 <<< 17`)
  in `flags`. Enabling it early lets a bot observe and handle the change ahead of the deadline.
  Note that only *gateway* payloads are redacted: probed against a real guild on 2026-09-19,
  `GET /guilds/{id}/channels` still returned every obfuscated channel in full, contrary to Discord's
  changelog
- **Channel flags** on `EDA.Channel` — `flag_pinned/0`, `flag_require_tag/0`,
  `flag_hide_media_download_options/0`, `flag_obfuscated/0`, `flag_spoiler/0`, plus
  `all_flags/0`, `has_flag?/2`, `flag_list/1` and `obfuscated_name/0`. `has_flag?/2` and
  `flag_list/1` accept a `%EDA.Channel{}`, a raw channel map as the cache stores it, a bare
  bitfield or `nil`
- **`EDA.Channel.obfuscated?/1`** — whether Discord redacted a channel because the bot cannot view
  it. Such channels still arrive over the gateway with `name` set to `"___hidden___"` and a single
  synthetic `@everyone` `VIEW_CHANNEL` deny in `permission_overwrites`; do not compute permissions
  from those overwrites

### Changed

- **`EDA.Permission.in_channel/3` now accounts for member timeouts.** Discord removes every
  permission except `VIEW_CHANNEL` and `READ_MESSAGE_HISTORY` from a timed-out member; EDA was
  reporting them as able to send messages, so a bot gating an action on `has_permission?/4` would
  wrongly allow a silenced member. Neither Nostrum nor JDA applies this — JDA documents the rule but
  leaves enforcement to the caller. The gate restricts and never grants, and guild owners and
  administrators are exempt, since Discord refuses to time them out at all
- **`EDA.Permission.in_channel/3` returns `{:error, :channel_obfuscated}`** for a channel Discord has
  redacted. The synthetic `@everyone` `VIEW_CHANNEL` deny is indistinguishable from a real overwrite,
  so computing from it would return a confident but meaningless answer; the ambiguity is surfaced to
  the caller instead. `has_permission?/4` maps it to `false`, like any other error
- Redaction **nulls** the sensitive fields rather than omitting them, so a channel that becomes
  obfuscated has its cached `name`, `topic`, `status` and `last_message_id` genuinely replaced by the
  merge in `EDA.Cache.Channel.update/2` — previously cached values do not survive. Redaction is
  selective: `position`, `parent_id`, `nsfw`, `bitrate` and `rate_limit_per_user` keep real values.
  Verified against a live guild
- Obfuscated channels are **kept in the cache** rather than dropped: "this channel exists and I
  cannot see it" is real information, and Discord expects apps that manage channels or compute
  permissions across a guild to detect that state. `EDA.Cache.channels/0` and
  `channels_for_guild/1` therefore include them — reject with `EDA.Channel.obfuscated?/1`, or skip
  them at admission with a `channels:` cache policy. Documented on `EDA.Cache`

## [0.3.0] - 2026-09-19

### Installation

```elixir
def deps do
  [
    {:eda, "~> 0.3.0"}
  ]
end
```

### Added

- **EDA.API.Message.pins/2** — one page of a channel's pins, with `pinned_at` timestamps and `has_more`
- **EDA.API.Channel.set_voice_status/3** / **EDA.Channel.set_voice_status/3** — set or clear a voice channel's status, plus the `VOICE_CHANNEL_STATUS_UPDATE` event and the `:status` field on `EDA.Channel`
- **EDA.Event.RateLimited** — gateway rate limit notifications (`opcode`, `retry_after`, `guild_id`, `nonce`), previously swallowed by `EDA.Event.Raw`
- `:reason` (audit log) on `EDA.API.Message.pin/3` and `unpin/3`, and on `EDA.Message.pin/2` and `unpin/2`

### Changed

- **Pins** now use `/channels/{id}/messages/pins`; the deprecated `/channels/{id}/pins` routes are gone. `EDA.API.Message.pinned/2` keeps returning `{:ok, [message]}` but paginates past the old 50-pin ceiling
- **EDA.Gateway.MemberChunker** throttles all-members OP 8 requests to one per guild per 30 seconds, queueing them instead of letting Discord drop them. Prefix searches and `user_ids` lookups are exempt. Configurable with `config :eda, member_chunk_cooldown_ms: 30_000`

### Fixed

- **Cache admission policies are now consulted once, with the real entity.** On the REST fallback path a custom `fn/3` or module policy was asked about the whole result with `nil` for both key and value, and then asked again per entity by the cache module. A policy that pattern matched on a map raised `FunctionClauseError`, and per-role decisions were impossible. `EDA.Cache.fetch_role/2` and the other `fetch_*` fallbacks now delegate straight to the cache modules, which apply the policy with the real key and value
- **`EDA.Voice.Dave.Native` specs now match what the NIF actually returns.** The Rust side returns `Result<T, Atom>`, which Rustler encodes as `{:ok, T}`, so `new_session/3` yields `{:ok, reference()}` and `create_key_package/1`, `process_proposals/4`, `encrypt_opus/2` and `decrypt_audio/3` are double wrapped as `{:ok, {:ok, binary()}}`. The getters (`ready?/1`, `get_epoch/1`, `status/1`, `can_passthrough?/2`, `protocol_version/1`) are wrapped too. Runtime behaviour is unchanged — `EDA.Voice.Dave.Manager` already normalised both shapes — but the published specs were misleading for anyone calling the NIF directly
- **`EDA.Modal.modal/7`** declared every input as `map()` while `modal/3..6` default the trailing inputs to `nil`, so each defaulted arity broke its own contract
- Removed unreachable clauses from private helpers in `EDA.Cache` and `EDA.Command.Option`

### Documentation

- Corrected the Gateway and Cache configuration examples in the README: the key is `gateway_encoding:` (not `encoding:`) and `:etf` is the default; `compress:` does not exist since zlib-stream is unconditional; shard overrides use a top-level `shards:` (`:auto`, an integer, or `{range, total}`) rather than `shard_count:` under `:gateway`; and `:cache` options are per entity, with no `evict_interval`
- `EDA.Gateway.Intents` no longer claims `:nonprivileged` is the default — `EDA.intents/0` falls back to `[:guilds]`

## [0.2.0] - 2026-04-04

### Installation

```elixir
def deps do
  [
    {:eda, "~> 0.2.0"}
  ]
end
```

### Added

- **EDA.Collector** — Discord.js-style `await` patterns for messages, reactions, components with filters, timeouts, and max count ([#4](https://github.com/qoyri/EDA/pull/4))
- **EDA.AutoDelete** — Timer-based auto-deletion using BEAM timer wheel. `delete_after:` option on `Message.create`, `Interaction.respond`, `Interaction.followup`
- **EDA.Color** — 30 named colors with individual functions, crypto-random generation (`Color.random()`), hex parsing, `:random` support in `Embed.color/2`
- **EDA.Mention** — User, channel, role, emoji, and timestamp formatting helpers
- **EDA.OAuth2** — Bot invite URL generator with permission atoms and scopes
- **EDA.API.SKU** / **Entitlement** / **Subscription** — Monetization API endpoints (beta)
- **Webhook** — `get_message/3`, `edit_message/4`, `delete_message/3`, `wait: true` option on `execute/3`
- **Thread** — `remove_member/2`, `get_member/2`, `list_members/1`
- **Message** — `forward/3` (message forwarding), `reply/2` (auto message_reference)
- **Command/Option** — `localize/3` for multi-language name/description translations
- **Component** — `disable_all/1` to recursively disable all buttons/selects
- **Embed** — `error/1` and `success/1` pre-styled presets
- **Interaction** — `selected_values/1`, `component_type/1`, `delete_source/1`, `defer_and_edit/3`
- **Member** — `move_voice/3` helper
- **Guild** — `icon_url/1` CDN helper
- **EDA.latency/1** — Gateway heartbeat latency shortcut
- **EDA.await_message/2**, **await_reaction/2**, **await_component/2** — Convenience wrappers

### Fixed

- **Ban.create** — `reason:` now sent as `X-Audit-Log-Reason` header instead of JSON body
- **Modal.get_values** — handles atom keys from parsed interaction structs
- **Component.section** — raises if `:accessory` is missing (Discord requires it)
- **parse_error** — includes Discord's `errors` field for validation details (50035)
- **Cache.me()** — returns `%EDA.User{}` struct instead of raw map
- **File.from_binary** — accepts byte lists for NIF `Vec<u8>` compatibility
- **User helpers** — `mention/1`, `avatar_url/1`, `display_name/1`, `bot?/1` accept raw maps from cache
- **ReadyTracker test** — stabilized flaky test with synchronous state reset
- **Interaction.respond** — `delete_after:` schedules deletion via interaction token
- **Interaction.delete_source** — works on ephemeral messages (uses type 6 DEFERRED_UPDATE_MESSAGE)

## [0.1.3] - 2026-03-07

### Installation

```elixir
def deps do
  [
    {:eda, "~> 0.1.3"}
  ]
end
```

### Added

- **Voice** — FFmpeg volume passthrough for voice playback (`play/3` with `volume:` option) ([#2](https://github.com/qoyri/EDA/pull/2) by [@christomitov](https://github.com/christomitov))

### Fixed

- **DAVE** — Fail closed on media encryption errors — stops playback cleanly instead of sending undecryptable raw Opus when DAVE encryption fails ([#3](https://github.com/qoyri/EDA/pull/3) by [@christomitov](https://github.com/christomitov))

### Acknowledgments

Thanks to [@christomitov](https://github.com/christomitov) for both contributions in this release.

## [0.1.2] - 2026-03-05

### Installation

```elixir
def deps do
  [
    {:eda, "~> 0.1.2"}
  ]
end
```

Requires Rust toolchain for the DAVE NIF (auto-compiled via Rustler on first `mix compile`).

### Fixed

- **DAVE** — Track `connected_clients` via OP 11/12/13 (`CLIENTS_CONNECT`/`CLIENTS_DISCONNECT`) and pass user IDs to `process_proposals` — MLS group now forms correctly in multi-user channels ([#2](https://github.com/qoyri/EDA/issues/2))
- **DAVE** — OP 24 `epoch=1` sole member reset — reset MLS group and send new key package so the group reforms when someone rejoins
- **DAVE** — OP 13 `client_disconnect` handler per DAVE spec (single `user_id` format), in addition to batch OP 12

### Added

- **DAVE** — `DirtyCpu` scheduling on 6 crypto NIFs (`encrypt_opus`, `decrypt_audio`, `process_proposals`, `process_commit`, `process_welcome`, `create_key_package`) — no longer blocks the BEAM scheduler ([#6](https://github.com/qoyri/EDA/issues/6))
- **DAVE** — `can_passthrough?/2` NIF + fallback in `decrypt_frame` — audio passes through during epoch transitions instead of being dropped ([#4](https://github.com/qoyri/EDA/issues/4))
- **DAVE** — New NIFs: `reinit/4`, `status/1`, `protocol_version/1`, `max_protocol_version/0` for full `davey` API coverage ([#5](https://github.com/qoyri/EDA/issues/5))

### Acknowledgments

Built on the solid DAVE foundation from [#1](https://github.com/qoyri/EDA/pull/1) by [@christomitov](https://github.com/christomitov). The improvements in this release build on top of that work — connected_clients tracking, DirtyCpu scheduling, passthrough fallback, and additional NIF bindings are all new code layered on the original PR's binary frame routing, key package flow, and error handling.

## [0.1.1] - 2026-03-05

### Fixed

- **DAVE** — Binary frame routing for OP 25/27/29/30, proper welcome/commit handling, improved error normalization ([#1](https://github.com/qoyri/EDA/pull/1) by [@christomitov](https://github.com/christomitov))
- **Voice** — Better reconnection handling, ETS playback progress table lifecycle, encrypt error differentiation (`:not_ready` vs `:encryption_failed`)

## [0.1.0] - 2026-02-18

### Added

- **Gateway** — WebSocket connection with automatic reconnection, heartbeat, resume, zlib compression, and ETF/JSON encoding
- **Sharding** — Shard manager with automatic shard count, member chunking, and per-shard ready tracking
- **REST API** — Resource-based API modules (Guild, Channel, Message, Member, Role, Emoji, Sticker, Webhook, Invite, Interaction, etc.) with full rate limiting
- **Cache** — ETS-backed cache for guilds, channels, users, members, roles, presences, and voice states with configurable eviction policies
- **Voice** — Voice connection with Opus audio sending/receiving, OGG file playback, AES-256-GCM and XChaCha20-Poly1305 encryption
- **DAVE** — Discord Audio/Video E2EE (experimental) via Rust NIF for MLS-based key ratcheting
- **Events** — Typed event structs for all Discord gateway events with `EDA.Consumer` callback pattern
- **Entities** — Struct-based models for all Discord objects (Guild, Channel, Message, Member, Role, User, etc.) with `Access` behaviour
- **Interactions** — Slash commands, components, modals, and autocomplete support
- **Permissions** — Bitfield-based permission calculations with channel overwrite resolution
- **Telemetry** — Built-in telemetry events for gateway, HTTP, and cache operations
