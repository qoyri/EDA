defmodule EDA.Gateway.EventDrainTest do
  @moduledoc """
  Consumer handlers run in plain processes; when the application stops, EDA.Gateway.EventDrain
  waits for those still running.
  """

  # NOT async — the handler counter is global.
  use ExUnit.Case

  defmodule Slow do
    def handle_event({_type, %EDA.Event.Raw{data: pid}}) do
      Process.sleep(80)
      send(pid, :handled)
    end
  end

  setup do
    previous = Application.get_env(:eda, :consumer)
    on_exit(fn -> Application.put_env(:eda, :consumer, previous) end)
    :ok
  end

  test "stopping waits for a handler still running" do
    Application.put_env(:eda, :consumer, Slow)
    counter = :persistent_term.get(:eda_event_task_counter)
    before = :counters.get(counter, 1)

    # An event type EDA does not type reaches the consumer as EDA.Event.Raw, its data this pid.
    EDA.Gateway.Events.dispatch("EDA_DRAIN_TEST", self())
    assert :counters.get(counter, 1) == before + 1

    {elapsed, :ok} = :timer.tc(fn -> EDA.Gateway.EventDrain.terminate(:shutdown, nil) end)

    assert_received :handled
    assert elapsed >= 50_000
    assert :counters.get(counter, 1) == before
  end

  test "a handler that runs too long does not hold the stop beyond the limit" do
    counter = :persistent_term.get(:eda_event_task_counter)
    :counters.add(counter, 1, 1)
    on_exit(fn -> :counters.sub(counter, 1, 1) end)

    {elapsed, :ok} = :timer.tc(fn -> EDA.Gateway.EventDrain.terminate(:shutdown, nil) end)
    assert elapsed in 4_900_000..5_500_000
  end
end
