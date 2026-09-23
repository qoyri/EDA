defmodule EDA.Gateway.EventDrain do
  @moduledoc false
  # Lets the consumer's handlers finish when the application stops.
  #
  # Events are handed to the consumer in plain processes, spawned without a supervisor call, which
  # costs a third of what `Task.Supervisor.start_child/2` did on every event. This process takes
  # the supervisor's other job: it is started before the gateway, so it stops after it — once no
  # event can arrive — and it then waits, up to five seconds, for the handlers still running.

  use GenServer

  @drain_timeout 5_000

  def start_link(_opts), do: GenServer.start_link(__MODULE__, nil, name: __MODULE__)

  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      shutdown: @drain_timeout + 1_000
    }
  end

  @impl true
  def init(nil) do
    Process.flag(:trap_exit, true)
    {:ok, nil}
  end

  @impl true
  def terminate(_reason, _state), do: wait(System.monotonic_time(:millisecond) + @drain_timeout)

  defp wait(deadline) do
    counter = :persistent_term.get(:eda_event_task_counter)

    cond do
      :counters.get(counter, 1) <= 0 ->
        :ok

      System.monotonic_time(:millisecond) >= deadline ->
        :ok

      true ->
        Process.sleep(10)
        wait(deadline)
    end
  end
end
