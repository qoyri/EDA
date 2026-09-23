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

    # One line, on purpose. This fires on every start without a token — including test
    # suites where that is deliberate — and used to be a nine-line block followed by a second
    # warning from the shard supervisor saying the same thing.
    unless token do
      Logger.warning(
        "[EDA] No Discord token configured, so the gateway will not connect. " <>
          ~s|Set it with config :eda, token: System.get_env("DISCORD_TOKEN").|
      )
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

      # Auto-delete message scheduler
      EDA.AutoDelete,

      # Task supervisor for background jobs (auto-delete)
      {Task.Supervisor, name: EDA.Gateway.TaskSupervisor},

      # Waits for the consumer's running handlers when the application stops
      EDA.Gateway.EventDrain,

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
