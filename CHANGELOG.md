# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

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

### Changed

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

### Security

- The DAVE NIF now builds against `davey` 0.1.4 instead of 0.1.1. The older lock pulled in OpenMLS
  and cryptography crates with published advisories — GHSA-8x3w-qj7j-gqhf (high),
  GHSA-435g-fcv3-8j26 and GHSA-g433-pq76-6cmf — and 0.1.4 also brings the library's encryption in
  line with Discord's reference implementation. Only projects that compile the NIF (voice with
  `dave: true`) are affected; they pick this up on the next build.

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
