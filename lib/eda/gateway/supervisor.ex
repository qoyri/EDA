defmodule EDA.Gateway.Supervisor do
  @moduledoc """
  Supervisor for the Gateway connection.

  Manages the WebSocket connection to Discord's Gateway,
  automatically restarting it if it crashes.
  """

  use Supervisor

  require Logger

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    token = Keyword.get(opts, :token)

    children =
      if token do
        [
          {EDA.Gateway.Connection, token: token}
        ]
      else
        Logger.warning("No token provided, Gateway will not connect")
        []
      end

    Supervisor.init(children, strategy: :one_for_one)
  end
end
