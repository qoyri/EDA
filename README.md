# EDA - Elixir Discord API

A modern Discord library for Elixir, inspired by JDA (Java Discord API).

## Features

- **WebSocket Gateway** - Real-time connection to Discord with automatic reconnection
- **REST API Client** - Full Discord REST API support with rate limiting
- **ETS Caching** - Fast O(1) lookups for guilds, users, and channels
- **Simple Consumer Pattern** - Easy event handling with pattern matching
- **OTP-Native** - Built on GenServers and Supervisors for reliability
- **Telemetry Integration** - Built-in observability

## Installation

Add `eda` to your dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:eda, "~> 0.1.0"}
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
# lib/my_bot/consumer.ex
defmodule MyBot.Consumer do
  @behaviour EDA.Consumer

  require Logger

  @impl true
  def handle_event({:MESSAGE_CREATE, msg}) do
    case msg["content"] do
      "!ping" ->
        EDA.REST.Client.create_message(msg["channel_id"], "Pong!")

      "!hello" ->
        author = msg["author"]["username"]
        EDA.REST.Client.create_message(msg["channel_id"], "Hello, #{author}!")

      _ ->
        :ignore
    end
  end

  @impl true
  def handle_event({:READY, data}) do
    Logger.info("Bot ready as #{data["user"]["username"]}!")
  end

  @impl true
  def handle_event(_event), do: :ok
end
```

### 3. Run your bot

```bash
export DISCORD_TOKEN="your_bot_token_here"
iex -S mix
```

## Gateway Intents

Control which events your bot receives:

```elixir
config :eda,
  intents: [:guilds, :guild_messages, :message_content]
```

Available intents:
- `:guilds` - Guild events
- `:guild_members` - Member events (privileged)
- `:guild_moderation` - Ban/unban events
- `:guild_expressions` - Emoji/sticker events
- `:guild_integrations` - Integration events
- `:guild_webhooks` - Webhook events
- `:guild_invites` - Invite events
- `:guild_voice_states` - Voice state events
- `:guild_presences` - Presence updates (privileged)
- `:guild_messages` - Message events in guilds
- `:guild_message_reactions` - Reaction events in guilds
- `:guild_message_typing` - Typing events in guilds
- `:direct_messages` - DM events
- `:direct_message_reactions` - Reaction events in DMs
- `:direct_message_typing` - Typing events in DMs
- `:message_content` - Access message content (privileged)
- `:guild_scheduled_events` - Scheduled event events
- `:auto_moderation_configuration` - AutoMod config events
- `:auto_moderation_execution` - AutoMod execution events

Shortcuts:
- `:all` - All intents including privileged
- `:nonprivileged` - All non-privileged intents

## REST API

Send messages and interact with Discord:

```elixir
# Send a message
EDA.REST.Client.create_message(channel_id, "Hello!")

# Send a message with an embed
EDA.REST.Client.create_message(channel_id, %{
  content: "Check this out!",
  embeds: [%{
    title: "Cool Embed",
    description: "Very nice",
    color: 0x5865F2
  }]
})

# Get guild info
{:ok, guild} = EDA.REST.Client.get_guild(guild_id)

# Add a reaction
EDA.REST.Client.create_reaction(channel_id, message_id, "👍")
```

## Caching

Access cached data with O(1) lookups:

```elixir
# Get the bot user
me = EDA.Cache.me()

# Get a guild
guild = EDA.Cache.get_guild(guild_id)

# Get all guilds
guilds = EDA.Cache.guilds()

# Get a user
user = EDA.Cache.get_user(user_id)

# Get a channel
channel = EDA.Cache.get_channel(channel_id)

# Get channels for a guild
channels = EDA.Cache.channels_for_guild(guild_id)

# Cache stats
EDA.Cache.guild_count()
EDA.Cache.user_count()
EDA.Cache.channel_count()
```

## Events

Common events you can handle:

| Event | Description |
|-------|-------------|
| `{:READY, data}` | Bot has connected and is ready |
| `{:MESSAGE_CREATE, msg}` | A message was created |
| `{:MESSAGE_UPDATE, msg}` | A message was edited |
| `{:MESSAGE_DELETE, data}` | A message was deleted |
| `{:GUILD_CREATE, guild}` | Bot joined a guild |
| `{:GUILD_DELETE, data}` | Bot left a guild |
| `{:CHANNEL_CREATE, channel}` | A channel was created |
| `{:CHANNEL_UPDATE, channel}` | A channel was updated |
| `{:CHANNEL_DELETE, channel}` | A channel was deleted |
| `{:INTERACTION_CREATE, interaction}` | Slash command or component interaction |

## Architecture

```
EDA.Supervisor
├── EDA.Cache.Supervisor
│   ├── EDA.Cache.Guild (ETS)
│   ├── EDA.Cache.User (ETS)
│   └── EDA.Cache.Channel (ETS)
├── EDA.REST.RateLimiter (GenServer)
└── EDA.Gateway.Supervisor
    └── EDA.Gateway.Connection (WebSockex)
```

## Comparison with Nostrum

| Feature | EDA | Nostrum |
|---------|-----|---------|
| WebSocket Library | WebSockex | Gun |
| HTTP Library | HTTPoison | Gun |
| Event Handling | Simple callbacks | GenStage (optional) |
| Caching | ETS (simple) | ETS/Mnesia (pluggable) |
| Sharding | Basic | Full support |
| Voice | Not yet | Supported |
| Learning Curve | Easy | Moderate |

EDA is designed to be simpler and more approachable, while Nostrum offers more advanced features for larger bots.

## Roadmap

- [ ] Slash commands support
- [ ] Voice channel support
- [ ] Multi-shard support
- [ ] GenStage-based event handling
- [ ] Pluggable cache backends
- [ ] Rate limit header parsing

## License

MIT License - see LICENSE file for details.

## Contributing

Contributions are welcome! Please feel free to submit issues and pull requests.
