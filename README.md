# EDA - Elixir Discord API

[![CI](https://github.com/qoyri/EDA/actions/workflows/ci.yml/badge.svg)](https://github.com/qoyri/EDA/actions/workflows/ci.yml)
[![Hex.pm](https://img.shields.io/hexpm/v/eda.svg)](https://hex.pm/packages/eda)
[![Hex Docs](https://img.shields.io/badge/hex-docs-blue.svg)](https://hexdocs.pm/eda)
[![License: MIT](https://img.shields.io/hexpm/l/eda.svg)](https://opensource.org/licenses/MIT)

A complete, production-grade Discord library for Elixir. 24 API modules, 68+ event types, full voice with DAVE E2EE, automatic sharding, and 1300+ tests.

## Why EDA?

- **Full Discord API coverage** — 24 resource-based REST modules: messages, guilds, channels, members, roles, commands, interactions, webhooks, threads, stages, polls, stickers, emojis, scheduled events, auto-moderation, monetization (SKU/entitlements/subscriptions), and more
- **Typed event structs** — 68+ gateway events across 7 categories (Guild, Message, Channel, Voice, Thread, Stage, Invite) with pattern matching, not raw maps
- **Voice with DAVE E2EE** — Opus audio send/receive, OGG playback, AES-256-GCM and XChaCha20-Poly1305 transport encryption, plus mandatory DAVE (Discord E2EE) via Rust NIF with DirtyCpu scheduling
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
    {:eda, "~> 0.2.0"}
  ]
end
```

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
EDA.API.Role.add(guild_id, user_id, role_id)

# Slash commands
EDA.API.Command.create_global(app_id, %{name: "ping", description: "Pong!"})

# Reactions, threads, webhooks...
EDA.API.Reaction.create(channel_id, message_id, "🔥")
EDA.API.Thread.create(channel_id, %{name: "Discussion", auto_archive_duration: 1440})
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
  policy: :all,           # :all | :none | MyPolicy | fn/3
  max_size: 10_000,       # Enable LRW eviction
  evict_interval: 60_000  # Eviction check interval (ms)
```

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
  encoding: :etf,      # :json (default) or :etf for binary encoding
  compress: true        # zlib transport compression
```

Sharding is automatic. EDA fetches the recommended shard count from Discord, launches shards with staggered timing, and tracks per-shard readiness. Override with:

```elixir
config :eda, :gateway,
  shard_count: 4  # Fixed shard count
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
