defmodule PingBot.Consumer do
  @moduledoc """
  Example Discord bot using EDA.

  This bot responds to:
  - `!ping` - Responds with "Pong!"
  - `!hello` - Greets the user
  - `!info` - Shows bot info
  - `!guilds` - Shows number of cached guilds

  ## Usage

  1. Set your bot token:

      export DISCORD_TOKEN="your_bot_token_here"

  2. Add this consumer to your config:

      config :eda,
        token: System.get_env("DISCORD_TOKEN"),
        intents: [:guilds, :guild_messages, :message_content],
        consumer: PingBot.Consumer

  3. Start the application:

      iex -S mix
  """

  @behaviour EDA.Consumer

  require Logger

  @impl true
  def handle_event({:MESSAGE_CREATE, msg}) do
    # Ignore bot messages
    if msg["author"]["bot"] do
      :ignore
    else
      handle_command(msg)
    end
  end

  @impl true
  def handle_event({:READY, data}) do
    user = data["user"]
    guilds = data["guilds"] || []

    Logger.info("""
    Bot is ready!
    Username: #{user["username"]}
    User ID: #{user["id"]}
    Guilds: #{length(guilds)}
    """)
  end

  @impl true
  def handle_event({:GUILD_CREATE, guild}) do
    Logger.debug("Joined guild: #{guild["name"]} (#{guild["id"]})")
  end

  @impl true
  def handle_event(_event) do
    :ok
  end

  # Command handling

  defp handle_command(%{"content" => "!ping", "channel_id" => channel_id}) do
    start = System.monotonic_time(:millisecond)
    {:ok, _} = EDA.REST.Client.create_message(channel_id, "Pong!")
    latency = System.monotonic_time(:millisecond) - start
    Logger.debug("Ping response sent in #{latency}ms")
  end

  defp handle_command(%{"content" => "!hello", "channel_id" => channel_id, "author" => author}) do
    username = author["username"]
    EDA.REST.Client.create_message(channel_id, "Hello, #{username}!")
  end

  defp handle_command(%{"content" => "!info", "channel_id" => channel_id}) do
    me = EDA.Cache.me()
    guild_count = EDA.Cache.guild_count()
    user_count = EDA.Cache.user_count()
    channel_count = EDA.Cache.channel_count()

    message = """
    **EDA Bot Info**
    Bot: #{me["username"]}
    Guilds: #{guild_count}
    Cached Users: #{user_count}
    Cached Channels: #{channel_count}
    Library: EDA v0.1.0
    """

    EDA.REST.Client.create_message(channel_id, message)
  end

  defp handle_command(%{"content" => "!guilds", "channel_id" => channel_id}) do
    guilds = EDA.Cache.guilds()

    guild_list =
      guilds
      |> Enum.take(10)
      |> Enum.map(fn g -> "- #{g["name"]}" end)
      |> Enum.join("\n")

    message =
      if length(guilds) > 10 do
        "**Guilds (showing 10 of #{length(guilds)}):**\n#{guild_list}"
      else
        "**Guilds:**\n#{guild_list}"
      end

    EDA.REST.Client.create_message(channel_id, message)
  end

  defp handle_command(_msg) do
    :ignore
  end
end
