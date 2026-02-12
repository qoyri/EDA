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
              EDA.REST.Client.create_message(msg["channel_id"], "Pong!")

            "!hello" ->
              author = msg["author"]["username"]
              EDA.REST.Client.create_message(msg["channel_id"], "Hello, \#{author}!")

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

  Events are tuples in the format `{event_type, data}` where:

  - `event_type` is an atom like `:MESSAGE_CREATE`, `:GUILD_CREATE`, etc.
  - `data` is a map containing the event payload from Discord

  ## Common Events

  - `{:READY, data}` - Bot has connected and is ready
  - `{:MESSAGE_CREATE, msg}` - A message was created
  - `{:MESSAGE_UPDATE, msg}` - A message was edited
  - `{:MESSAGE_DELETE, data}` - A message was deleted
  - `{:GUILD_CREATE, guild}` - Bot joined a guild or guild became available
  - `{:GUILD_DELETE, data}` - Bot left a guild or guild became unavailable
  - `{:CHANNEL_CREATE, channel}` - A channel was created
  - `{:INTERACTION_CREATE, interaction}` - A slash command or component interaction

  See Discord's documentation for the full list of events.
  """

  @doc """
  Called when a Gateway event is received.

  The event is a tuple of `{event_type, data}`.
  """
  @callback handle_event(event :: {atom(), map()}) :: any()
end
