# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
