# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
