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

    # Event dispatch concurrency counter
    counter = :counters.new(1, [:write_concurrency])
    :persistent_term.put(:eda_event_task_counter, counter)

    children = [
      # Cache supervisor - starts ETS tables
      EDA.Cache.Supervisor,

      # Rate limiter for REST API
      EDA.HTTP.RateLimiter,

      # Voice supervisor - manages voice connections
      EDA.Voice.Supervisor,

      # Event collector for await patterns
      EDA.Collector,

      # Task supervisor for event dispatch
      {Task.Supervisor, name: EDA.Gateway.TaskSupervisor},

      # Member chunker for OP 8 (Request Guild Members)
      EDA.Gateway.MemberChunker,

      # Ready tracker — fires SHARD_READY / ALL_SHARDS_READY after startup
      EDA.Gateway.ReadyTracker,

      # Gateway shard supervisor - manages sharded WebSocket connections
      {EDA.Gateway.ShardSupervisor, token: token}
    ]

    opts = [strategy: :one_for_one, name: EDA.Supervisor]

    Logger.info("Starting EDA v#{Application.spec(:eda, :vsn)}")

    Supervisor.start_link(children, opts)
  end
end
