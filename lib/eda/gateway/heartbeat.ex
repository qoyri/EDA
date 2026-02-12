defmodule EDA.Gateway.Heartbeat do
  @moduledoc """
  Manages heartbeat timing for the Gateway connection.

  Discord requires regular heartbeats to keep the connection alive.
  The interval is provided by Discord in the HELLO payload.
  """

  @doc """
  Starts the heartbeat timer.

  Returns a reference that can be used to cancel the timer.
  Adds jitter to prevent thundering herd.
  """
  @spec start(integer()) :: reference()
  def start(interval) do
    # Add jitter (0-10% of interval)
    jitter = :rand.uniform(div(interval, 10))
    Process.send_after(self(), {:heartbeat}, interval + jitter)
  end

  @doc """
  Cancels a pending heartbeat timer.
  """
  @spec cancel(reference() | nil) :: :ok
  def cancel(nil), do: :ok

  def cancel(ref) do
    Process.cancel_timer(ref)
    :ok
  end
end
