defmodule EDA.Application do
  @moduledoc """
  Main application supervisor for EDA.

  Starts the supervision tree including:
  - Cache supervisors (ETS tables for guilds, users, channels)
  - Rate limiter for REST API
  - Gateway connection (WebSocket to Discord)
  """

  use Application

  require Logger

  @impl true
  def start(_type, _args) do
    token = Application.get_env(:eda, :token)

    unless token do
      Logger.warning("""
      No Discord token configured. Set it in your config:

          config :eda, token: "your_bot_token"

      Or via environment variable:

          config :eda, token: System.get_env("DISCORD_TOKEN")
      """)
    end

    children = [
      # Cache supervisor - starts ETS tables
      EDA.Cache.Supervisor,

      # Rate limiter for REST API
      EDA.REST.RateLimiter,

      # Voice supervisor - manages voice connections
      EDA.Voice.Supervisor,

      # Gateway supervisor - manages WebSocket connection
      {EDA.Gateway.Supervisor, token: token}
    ]

    opts = [strategy: :one_for_one, name: EDA.Supervisor]

    Logger.info("Starting EDA v#{Application.spec(:eda, :vsn)}")

    Supervisor.start_link(children, opts)
  end
end
