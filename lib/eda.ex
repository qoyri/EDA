defmodule EDA do
  @moduledoc """
  EDA - Elixir Discord API

  A modern Discord library for Elixir, inspired by JDA (Java Discord API).

  ## Quick Start

  1. Add your bot token to config:

      config :eda,
        token: System.get_env("DISCORD_TOKEN"),
        intents: [:guilds, :guild_messages, :message_content]

  2. Create a consumer module:

      defmodule MyBot.Consumer do
        @behaviour EDA.Consumer

        def handle_event({:MESSAGE_CREATE, msg}) do
          if msg["content"] == "!ping" do
            EDA.REST.Client.create_message(msg["channel_id"], "Pong!")
          end
        end

        def handle_event(_), do: :ok
      end

  3. Register your consumer:

      config :eda, consumer: MyBot.Consumer

  4. Start your application and the bot will connect automatically!

  ## Features

  - WebSocket Gateway connection with automatic reconnection
  - REST API client with rate limiting
  - ETS-based caching for guilds, users, and channels
  - Simple consumer behaviour for handling events
  - Telemetry integration for observability
  """

  @doc """
  Returns the configured bot token.
  """
  @spec token() :: String.t() | nil
  def token do
    Application.get_env(:eda, :token)
  end

  @doc """
  Returns the configured gateway intents as a bitfield.
  """
  @spec intents() :: integer()
  def intents do
    Application.get_env(:eda, :intents, [:guilds])
    |> EDA.Gateway.Intents.to_bitfield()
  end

  @doc """
  Returns the configured consumer module.
  """
  @spec consumer() :: module() | nil
  def consumer do
    Application.get_env(:eda, :consumer)
  end
end
