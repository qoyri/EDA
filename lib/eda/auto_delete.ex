defmodule EDA.AutoDelete do
  @moduledoc """
  Automatic message deletion scheduler.

  Manages timed message deletions using the BEAM's timer wheel — efficient
  for thousands of concurrent timers with zero per-timer process overhead.

  ## How it works

  1. `schedule/3` registers a deletion via `Process.send_after` (O(1) insert)
  2. When the timer fires, a Task is spawned to call `Message.delete` with
     low priority so deletions never starve important API calls
  3. The existing `EDA.HTTP.RateLimiter` handles 429s automatically

  ## Usage

  Typically used via the `delete_after:` option on message creation:

      EDA.API.Message.create(channel_id, content: "Temporary!", delete_after: 10_000)

  Or directly:

      EDA.AutoDelete.schedule(channel_id, message_id, 30_000)
  """

  use GenServer

  require Logger

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @doc """
  Schedules a message for deletion after `delay_ms` milliseconds.

  This is a non-blocking cast. The deletion will be executed asynchronously
  via `Task.Supervisor` with low priority through the rate limiter.

  Does nothing if `delay_ms` is `nil`.

  ## Examples

      EDA.AutoDelete.schedule("channel_id", "message_id", 30_000)
  """
  @spec schedule(String.t(), String.t(), non_neg_integer() | nil) :: :ok
  def schedule(_channel_id, _message_id, nil), do: :ok

  def schedule(channel_id, message_id, delay_ms)
      when is_integer(delay_ms) and delay_ms >= 0 do
    GenServer.cast(__MODULE__, {:schedule_message, channel_id, message_id, delay_ms})
  end

  @doc """
  Schedules an interaction response for deletion after `delay_ms` milliseconds.

  Uses the interaction token to delete the original response — works for both
  ephemeral and non-ephemeral responses. Unlike `schedule/3`, this doesn't need
  a message ID since interaction responses are deleted via their token.

  Does nothing if `delay_ms` is `nil`.

  ## Examples

      EDA.AutoDelete.schedule_interaction_response(app_id, token, 10_000)
  """
  @spec schedule_interaction_response(String.t(), String.t(), non_neg_integer() | nil) :: :ok
  def schedule_interaction_response(_app_id, _token, nil), do: :ok

  def schedule_interaction_response(app_id, token, delay_ms)
      when is_integer(delay_ms) and delay_ms >= 0 do
    GenServer.cast(__MODULE__, {:schedule_interaction, app_id, token, delay_ms})
  end

  # ── GenServer Callbacks ─────────────────────────────────────────────

  @impl true
  def init(:ok), do: {:ok, %{}}

  @impl true
  def handle_cast({:schedule_message, channel_id, message_id, delay_ms}, state) do
    Process.send_after(self(), {:delete_message, channel_id, message_id}, delay_ms)
    {:noreply, state}
  end

  def handle_cast({:schedule_interaction, app_id, token, delay_ms}, state) do
    Process.send_after(self(), {:delete_interaction, app_id, token}, delay_ms)
    {:noreply, state}
  end

  @impl true
  def handle_info({:delete_message, channel_id, message_id}, state) do
    Task.Supervisor.start_child(EDA.Gateway.TaskSupervisor, fn ->
      case EDA.API.Message.delete(channel_id, message_id) do
        :ok ->
          :ok

        {:error, reason} ->
          Logger.debug(
            "AutoDelete: failed to delete #{message_id} in #{channel_id}: #{inspect(reason)}"
          )
      end
    end)

    {:noreply, state}
  end

  def handle_info({:delete_interaction, app_id, token}, state) do
    Task.Supervisor.start_child(EDA.Gateway.TaskSupervisor, fn ->
      case EDA.API.Interaction.delete_response(app_id, token) do
        :ok ->
          :ok

        {:error, reason} ->
          Logger.debug("AutoDelete: failed to delete interaction response: #{inspect(reason)}")
      end
    end)

    {:noreply, state}
  end
end
