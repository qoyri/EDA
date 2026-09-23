defmodule EDA.Consumer do
  @moduledoc """
  Behaviour for handling Discord Gateway events.

  Implement this behaviour to handle events from Discord.

  ## Example

      defmodule MyBot.Consumer do
        @behaviour EDA.Consumer

        require Logger

        @impl true
        def handle_event({:MESSAGE_CREATE, msg}) do
          case msg["content"] do
            "!ping" ->
              EDA.API.Message.create(msg["channel_id"], "Pong!")

            "!hello" ->
              author = msg["author"]["username"]
              EDA.API.Message.create(msg["channel_id"], "Hello, \#{author}!")

            _ ->
              :ignore
          end
        end

        @impl true
        def handle_event({:READY, data}) do
          Logger.info("Bot ready as \#{data["user"]["username"]}!")
        end

        @impl true
        def handle_event(_event) do
          :ok
        end
      end

  ## Event Format

  Events are tuples in the format `{event_type, struct}` where:

  - `event_type` is an atom like `:MESSAGE_CREATE`, `:GUILD_CREATE`, etc.
  - `struct` is a typed struct (e.g. `%EDA.Message{}` for a message)

  Struct fields are accessible via dot notation (`msg.content`), atom keys
  (`msg[:content]`), or string keys (`msg["content"]`) thanks to the custom
  Access implementation — so existing code using string keys still works.

  Nested maps (like `author`, `member`) remain string-keyed:
  `msg.author["username"]` or `msg["author"]["username"]`.

  ## Common Events

  - `{:READY, %EDA.Event.Ready{}}` - Bot has connected and is ready
  - `{:MESSAGE_CREATE, %EDA.Message{}}` - A message was created
  - `{:MESSAGE_UPDATE, %EDA.Message{}}` - A message was edited
  - `{:MESSAGE_DELETE, %EDA.Event.MessageDelete{}}` - A message was deleted
  - `{:GUILD_CREATE, %EDA.Event.GuildCreate{}}` - Bot joined a new guild at runtime
  - `{:GUILD_AVAILABLE, %EDA.Event.GuildCreate{}}` - A guild finished loading during startup
  - `{:GUILD_DELETE, %EDA.Event.GuildDelete{}}` - Bot was removed from a guild
  - `{:GUILD_UNAVAILABLE, %EDA.Event.GuildDelete{}}` - A guild went offline (Discord outage)
  - `{:SHARD_READY, %EDA.Event.ShardReady{}}` - A shard finished loading all its guilds
  - `{:ALL_SHARDS_READY, %EDA.Event.AllShardsReady{}}` - All shards are ready
  - `{:CHANNEL_CREATE, %EDA.Event.ChannelCreate{}}` - A channel was created
  - `{:INTERACTION_CREATE, %EDA.Event.InteractionCreate{}}` - A slash command or component interaction
  - `{:GATEWAY_CLOSE, %EDA.Event.GatewayClose{}}` - A shard disconnected from the gateway
  - `{:SESSION_RESUMED, %EDA.Event.SessionResumed{}}` - A shard resumed its previous session

  Unrecognized events are wrapped in `%EDA.Event.Raw{}` for forward compatibility.

  See Discord's documentation for the full list of events.
  """

  @type event :: {atom(), EDA.Event.event()}

  @doc """
  Called when a Gateway event is received.

  The event is a tuple of `{event_type, struct}`.
  """
  @callback handle_event(event()) :: any()
end
