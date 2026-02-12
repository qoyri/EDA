# EDA Examples

Example bots and usage patterns for EDA.

## PingBot

The basic ping bot is included in `lib/ping_bot.ex` and will be compiled automatically.

To use it, configure your bot:

```elixir
# config/config.exs
config :eda,
  token: System.get_env("DISCORD_TOKEN"),
  intents: [:guilds, :guild_messages, :message_content],
  consumer: PingBot.Consumer
```

Then run:

```bash
export DISCORD_TOKEN="your_token_here"
iex -S mix
```

## Commands

- `!ping` - Responds with "Pong!"
- `!hello` - Greets you by name
- `!info` - Shows bot statistics
- `!guilds` - Lists cached guilds

## Creating Your Own Bot

```elixir
defmodule MyBot.Consumer do
  @behaviour EDA.Consumer

  @impl true
  def handle_event({:MESSAGE_CREATE, msg}) do
    case msg["content"] do
      "!ping" ->
        EDA.REST.Client.create_message(msg["channel_id"], "Pong!")
      _ ->
        :ok
    end
  end

  @impl true
  def handle_event(_), do: :ok
end
```
