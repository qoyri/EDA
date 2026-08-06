# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- **EDA.API.Message.pins/2** — one page of a channel's pins, with `pinned_at` timestamps and `has_more`
- **EDA.API.Channel.set_voice_status/3** / **EDA.Channel.set_voice_status/3** — set or clear a voice channel's status, plus the `VOICE_CHANNEL_STATUS_UPDATE` event and the `:status` field on `EDA.Channel`
- **EDA.Event.RateLimited** — gateway rate limit notifications (`opcode`, `retry_after`, `guild_id`, `nonce`), previously swallowed by `EDA.Event.Raw`
- `:reason` (audit log) on `EDA.API.Message.pin/3` and `unpin/3`, and on `EDA.Message.pin/2` and `unpin/2`

### Changed

- **Pins** now use `/channels/{id}/messages/pins`; the deprecated `/channels/{id}/pins` routes are gone. `EDA.API.Message.pinned/2` keeps returning `{:ok, [message]}` but paginates past the old 50-pin ceiling
- **EDA.Gateway.MemberChunker** throttles all-members OP 8 requests to one per guild per 30 seconds, queueing them instead of letting Discord drop them. Prefix searches and `user_ids` lookups are exempt. Configurable with `config :eda, member_chunk_cooldown_ms: 30_000`

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
