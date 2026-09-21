# EDA - Elixir Discord API

[![CI](https://github.com/qoyri/EDA/actions/workflows/ci.yml/badge.svg)](https://github.com/qoyri/EDA/actions/workflows/ci.yml)
[![Hex.pm](https://img.shields.io/hexpm/v/eda.svg)](https://hex.pm/packages/eda)
[![Hex Docs](https://img.shields.io/badge/hex-docs-blue.svg)](https://hexdocs.pm/eda)
[![License: MIT](https://img.shields.io/hexpm/l/eda.svg)](https://opensource.org/licenses/MIT)

A complete, production-grade Discord library for Elixir. 26 API modules, 70+ event types, full voice with DAVE E2EE, automatic sharding, and 1500+ tests.

## Why EDA?

- **Full Discord API coverage** — 26 resource-based REST modules: the bot's own application, messages, guilds, channels, members, roles, commands, interactions, webhooks, threads, stages, polls, stickers, emojis, soundboard, scheduled events, auto-moderation, monetization (SKU/entitlements/subscriptions), and more
- **Typed event structs** — 70+ gateway events across 8 categories (Guild, Message, Channel, Voice, Thread, Stage, Invite, Soundboard) with pattern matching, not raw maps
- **Voice with DAVE E2EE** — Opus audio send/receive, OGG playback, AES-256-GCM and XChaCha20-Poly1305 transport encryption, plus DAVE (Discord's end-to-end encryption, required for voice since March 2026) via a precompiled native library — no Rust toolchain needed
- **Modals with every field Discord offers** — labels, text fields, select menus, file uploads, radio groups, checkbox groups and checkboxes, checked against Discord's limits when the modal is built, and a `get_values/1` that returns each answer in its natural shape
- **Smart sharding** — Auto shard count from `/gateway/bot`, staggered startup respecting `max_concurrency`, per-shard ready tracking, exponential backoff with jitter
- **Configurable cache** — ETS-backed O(1) lookups for 7 entity types (guilds, channels, users, members, roles, presences, voice states) with admission policies and LRW eviction
- **ETF + zlib** — Binary ETF encoding and zlib-stream compression for lower bandwidth and faster deserialization
- **DX helpers** — Event collectors (`await_message`, `await_component`), auto-delete messages, `Embed.error/success`, `Component.disable_all`, `Interaction.delete_source/defer_and_edit`, `Mention` formatting, `Color.random()`, and more
- **25 entity structs** — First-class structs with `Access` behaviour for all Discord objects
- **Telemetry built-in** — Instrument gateway, HTTP, cache, and DAVE operations out of the box
- **OTP-native** — Supervised GenServers, DynamicSupervisors, and proper fault tolerance

## Installation

```elixir
def deps do
  [
    {:eda, "~> 0.4.1"}
  ]
end
```

That is all a bot needs — unless it joins voice channels.

### Voice

Since March 2026 Discord only accepts end-to-end encrypted voice, using its **DAVE** protocol, for
DMs, group DMs, voice channels and Go Live — everything except Stage channels. A voice connection that
does not offer DAVE is refused with close code `4017`.

EDA speaks DAVE through a native library, which it downloads precompiled when it compiles — for
Linux (x86-64, ARM64, ARMv7 and RISC-V; glibc and musl), macOS, Windows and FreeBSD. So voice needs
no extra dependency and no configuration: DAVE is on as soon as the library is loaded.

On another platform, or to compile without network access, build it from source instead. That needs
Rust (for example through [rustup](https://rustup.rs)) and Rustler:

```elixir
{:rustler, "~> 0.35"}
```

```elixir
config :rustler_precompiled, :force_build, eda: true
```

If the library cannot be obtained, EDA still compiles and everything but voice works: compilation
prints a warning, and voice connections are refused with `4017`, which EDA logs with the reason.
`config :eda, dave: false` turns DAVE off, for a bot that only uses Stage channels.

## Quick Start

### 1. Configure your bot

```elixir
# config/config.exs
config :eda,
  token: System.get_env("DISCORD_TOKEN"),
  intents: [:guilds, :guild_messages, :message_content],
  consumer: MyBot.Consumer
```

### 2. Create a consumer

```elixir
defmodule MyBot.Consumer do
  @behaviour EDA.Consumer

  @impl true
  def handle_event({:MESSAGE_CREATE, msg}) do
    if msg.content == "!ping" do
      EDA.API.Message.create(msg.channel_id, "Pong!")
    end
  end

  @impl true
  def handle_event({:READY, ready}) do
    IO.puts("Online as #{ready.user.username}!")
  end

  @impl true
  def handle_event(_event), do: :ok
end
```

### 3. Run

```bash
DISCORD_TOKEN="your_token" iex -S mix
```

## REST API

```elixir
# Messages
EDA.API.Message.create(channel_id, "Hello!")
EDA.API.Message.create(channel_id, content: "With embed", embeds: [%{title: "Hey", color: 0x5865F2}])

# Guilds & members
{:ok, guild} = EDA.API.Guild.get(guild_id)
{:ok, member} = EDA.API.Member.get(guild_id, user_id)
EDA.API.Member.add_role(guild_id, user_id, role_id)

# Slash commands
EDA.API.Command.create_global(%{name: "ping", description: "Pong!"})

# Reactions, threads, webhooks...
EDA.API.Reaction.create(channel_id, message_id, "🔥")
EDA.API.Thread.start(channel_id, name: "Discussion", type: 11, auto_archive_duration: 1440)
```

## DX Helpers

```elixir
# Collectors — await events with filters
{:ok, reply} = EDA.await_message(fn msg ->
  msg.channel_id == channel_id and msg.author["id"] == user_id
end, timeout: 30_000)

# Auto-delete messages after a delay
EDA.API.Message.create(channel_id, content: "Temporary!", delete_after: 10_000)

# Pre-styled embeds
EDA.Embed.error("Something went wrong")
EDA.Embed.success("User banned successfully")

# Interaction workflows
EDA.Interaction.delete_source(interaction)  # Delete the button message
EDA.Interaction.defer_and_edit(interaction, fn -> do_work(); "Done!" end)
EDA.Interaction.respond(interaction, content: "Bye!", delete_after: 5_000)

# Disable all buttons after interaction
disabled = EDA.Component.disable_all(message["components"])

# Reply to a message
EDA.API.Message.reply(msg, "Got it!")

# Mentions & formatting
EDA.Mention.user("123")                #=> "<@123>"
EDA.Mention.timestamp(unix, :R)        #=> "<t:1700000000:R>"

# Colors
EDA.Color.random()                     #=> 0xA3F29C (crypto-random)
EDA.Embed.new() |> EDA.Embed.color(:random)
```

## Cache

```elixir
EDA.Cache.me()                              # Bot user
EDA.Cache.get_guild(guild_id)               # Single guild
EDA.Cache.guilds()                          # All guilds
EDA.Cache.get_channel(channel_id)           # Single channel
EDA.Cache.channels_for_guild(guild_id)      # Guild channels
EDA.Cache.guild_count()                     # Stats
```

Configure cache admission per entity:

```elixir
config :eda, :cache,
  guilds: [],
  users: [max_size: 100_000],   # LRW eviction once the table exceeds this size
  members: [policy: :none],     # :all (default) | :none | MyPolicy | fn/3
  presences: [policy: :none],
  channels: [
    policy: fn _entity, _key, ch ->
      if ch["type"] in [0, 2, 5], do: :cache, else: :skip
    end
  ]
```

Channels the bot cannot view are **kept in the cache**, with their metadata redacted by Discord
(`name` becomes `"___hidden___"`). Reject them with `EDA.Channel.obfuscated?/1` before showing a
channel list, or skip them at admission with a `channels:` policy. See the "Obfuscated channels"
section of `EDA.Cache`.

Options are set **per entity**, not globally. The configurable caches are `:guilds`, `:users`,
`:channels`, `:members`, `:roles`, `:voice_states` and `:presences`; each accepts `:policy` and
`:max_size`. Caches left out use the defaults (`policy: :all`, no size limit). The eviction sweep
interval is fixed and not configurable.

### Storage backend

Where entries live is a separate choice from which entries are kept. The default stores them in
ETS, local to the node; `EDA.Cache.Adapter.NoOp` stores nothing; and `EDA.Cache.Adapter.Mnesia`
shares one cache across a cluster, so a node that restarts rejoins it warm:

```elixir
config :eda,
  cache_adapter: EDA.Cache.Adapter.Mnesia,
  cache_mnesia: [copies: :ram_copies, nodes: [node()]]
```

The Mnesia adapter needs `:mnesia` in your own application's `:extra_applications` — EDA does
not start it for bots that never use it. Admission policies, `max_size` and eviction sit above the
adapter, so they apply unchanged to any backend, including one of your own implementing
`EDA.Cache.Adapter`.

## Events

| Event | Description |
|-------|-------------|
| `{:MESSAGE_CREATE, msg}` | Message created |
| `{:INTERACTION_CREATE, interaction}` | Slash command / component / modal |
| `{:GUILD_CREATE, guild}` | Guild available |
| `{:GUILD_MEMBER_ADD, member}` | Member joined |
| `{:VOICE_STATE_UPDATE, state}` | Voice state changed |
| `{:CHANNEL_CREATE, channel}` | Channel created |
| `{:THREAD_CREATE, thread}` | Thread created |
| `{:AUTO_MODERATION_ACTION_EXECUTION, action}` | AutoMod triggered |

Plus 60+ more — see [HexDocs](https://hexdocs.pm/eda) for the full list.

## Gateway

```elixir
config :eda,
  intents: [:guilds, :guild_messages, :message_content],
  # or :all, :nonprivileged
  gateway_encoding: :etf   # :etf (default, binary) or :json
```

zlib-stream transport compression is always enabled and has no configuration option.

Gateway capabilities let you opt into a protocol change before Discord enforces it:

```elixir
config :eda, capabilities: [:channel_obfuscation]
```

`:channel_obfuscation` becomes mandatory for all bots on **2026-11-16**. Channels the bot cannot see
are still dispatched over the gateway, but redacted — `name` becomes `"___hidden___"` and `flags`
carry `CHANNEL_OBFUSCATED`. Discord's changelog says `GET /guilds/{id}/channels` omits them; probed
against a real guild, REST still returned them unredacted, so do not rely on either source to hide a
channel. Enabling it early lets you see the redacted payloads and adapt caching and permission checks
before the deadline. Unset by default.

Sharding is automatic. EDA fetches the recommended shard count from Discord, launches shards with staggered timing, and tracks per-shard readiness. Override with:

```elixir
config :eda, shards: :auto        # Discord's recommended count (default)
config :eda, shards: 4            # Fixed count — this node runs shards 0..3
config :eda, shards: {0..1, 4}    # This node runs shards 0 and 1 out of 4 total
```

## Architecture

```
EDA.Application
├── EDA.Cache.Supervisor
│   ├── EDA.Cache.Guild      (ETS)
│   ├── EDA.Cache.Channel    (ETS)
│   ├── EDA.Cache.User       (ETS)
│   ├── EDA.Cache.Member     (ETS)
│   ├── EDA.Cache.Role       (ETS)
│   ├── EDA.Cache.Presence   (ETS)
│   ├── EDA.Cache.VoiceState (ETS)
│   └── EDA.Cache.Evictor
├── EDA.HTTP.RateLimiter
├── EDA.Voice.Supervisor
├── EDA.Collector              (event await patterns)
├── EDA.AutoDelete             (timer-based message cleanup)
├── Task.Supervisor            (async event dispatch)
├── EDA.Gateway.MemberChunker
├── EDA.Gateway.ReadyTracker
└── EDA.Gateway.ShardSupervisor
    ├── EDA.Gateway.ShardManager
    └── EDA.Gateway.Connection (per shard)
```

## Documentation

Full documentation is available on [HexDocs](https://hexdocs.pm/eda).

## License

MIT — see [LICENSE](LICENSE) for details.

## Contributing

Contributions are welcome! Open an issue or submit a pull request.
