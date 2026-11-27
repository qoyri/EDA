defmodule EDA.Gateway.TaskSupervisorTest do
  use ExUnit.Case

  alias EDA.Gateway.Events

  setup do
    # The counter is global, and a handler dispatched by the previous test may still be
    # running. Zeroing the counter under it let its decrement land afterwards, at -1, in
    # whichever test ran next. Wait for those handlers instead; the tests that block theirs
    # forever release them in `release_blocked/1`.
    counter = :persistent_term.get(:eda_event_task_counter)
    wait_until(fn -> :counters.get(counter, 1) == 0 end)

    # Register test process so supervised tasks can send messages back
    Process.register(self(), :task_supervisor_test)

    on_exit(fn ->
      try do
        Process.unregister(:task_supervisor_test)
      rescue
        _ -> :ok
      end
    end)

    :ok
  end

  describe "TaskSupervisor" do
    test "is alive after application start" do
      pid = Process.whereis(EDA.Gateway.TaskSupervisor)
      assert pid != nil
      assert Process.alive?(pid)
    end
  end

  describe "supervised dispatch" do
    test "dispatches events via Task.Supervisor" do
      Application.put_env(:eda, :consumer, __MODULE__.EchoConsumer)

      on_exit(fn ->
        Application.delete_env(:eda, :consumer)
      end)

      Events.dispatch("MESSAGE_CREATE", %{
        "content" => "test",
        "author" => %{"id" => "1", "username" => "bot"}
      })

      # Give the async task time to execute
      Process.sleep(50)

      assert_receive {:event, {:MESSAGE_CREATE, %EDA.Message{content: "test"}}}, 500
    end

    test "counter decrements after task completion" do
      Application.put_env(:eda, :consumer, __MODULE__.EchoConsumer)

      on_exit(fn ->
        Application.delete_env(:eda, :consumer)
      end)

      counter = :persistent_term.get(:eda_event_task_counter)

      Events.dispatch("MESSAGE_CREATE", %{
        "content" => "hi",
        "author" => %{"id" => "1", "username" => "bot"}
      })

      Process.sleep(50)

      assert :counters.get(counter, 1) == 0
    end

    test "drops events when max concurrency reached" do
      Application.put_env(:eda, :consumer, __MODULE__.BlockingConsumer)
      Application.put_env(:eda, :max_event_concurrency, 2)

      on_exit(fn ->
        Application.delete_env(:eda, :consumer)
        Application.delete_env(:eda, :max_event_concurrency)
      end)

      # Attach telemetry handler to capture drops
      test_pid = self()

      :telemetry.attach(
        "test-drop-handler",
        [:eda, :gateway, :event_dropped],
        fn _event, measurements, metadata, _config ->
          send(test_pid, {:dropped, measurements, metadata})
        end,
        nil
      )

      on_exit(fn ->
        :telemetry.detach("test-drop-handler")
      end)

      # Spawn 2 blocking tasks to fill capacity
      Events.dispatch("TEST_EVENT", %{})
      Events.dispatch("TEST_EVENT", %{})

      blocked =
        for _ <- 1..2 do
          assert_receive {:blocked, pid}, 500
          pid
        end

      on_exit(fn -> release_blocked(blocked) end)

      # This one should be dropped
      Events.dispatch("TEST_EVENT", %{})

      assert_receive {:dropped, %{count: 1}, %{event_type: "TEST_EVENT"}}, 500
    end

    test "crash in consumer does not crash supervisor" do
      Application.put_env(:eda, :consumer, __MODULE__.CrashingConsumer)

      on_exit(fn ->
        Application.delete_env(:eda, :consumer)
      end)

      sup_pid = Process.whereis(EDA.Gateway.TaskSupervisor)

      Events.dispatch("MESSAGE_CREATE", %{
        "content" => "crash",
        "author" => %{"id" => "1", "username" => "bot"}
      })

      Process.sleep(50)

      assert Process.alive?(sup_pid)
    end

    test "an interaction is dispatched even at capacity — Discord gives no second chance" do
      Application.put_env(:eda, :consumer, __MODULE__.EchoConsumer)
      Application.put_env(:eda, :max_event_concurrency, 0)

      on_exit(fn ->
        Application.delete_env(:eda, :consumer)
        Application.delete_env(:eda, :max_event_concurrency)
      end)

      Events.dispatch("INTERACTION_CREATE", %{"id" => "1", "type" => 2, "token" => "t"})

      assert_receive {:event, {:INTERACTION_CREATE, %EDA.Event.InteractionCreate{id: "1"}}}, 500
    end

    test "exit and throw are logged with the event, like an exception" do
      import ExUnit.CaptureLog

      on_exit(fn -> Application.delete_env(:eda, :consumer) end)

      for consumer <- [__MODULE__.ExitingConsumer, __MODULE__.ThrowingConsumer] do
        Application.put_env(:eda, :consumer, consumer)

        log =
          capture_log(fn ->
            Events.dispatch("MESSAGE_CREATE", %{
              "content" => "x",
              "author" => %{"id" => "1", "username" => "bot"}
            })

            Process.sleep(100)
          end)

        assert log =~ "Consumer error handling MESSAGE_CREATE"
      end

      assert :counters.get(:persistent_term.get(:eda_event_task_counter), 1) == 0
    end

    test "telemetry emitted on drop" do
      Application.put_env(:eda, :consumer, __MODULE__.BlockingConsumer)
      Application.put_env(:eda, :max_event_concurrency, 0)

      on_exit(fn ->
        Application.delete_env(:eda, :consumer)
        Application.delete_env(:eda, :max_event_concurrency)
      end)

      test_pid = self()

      :telemetry.attach(
        "test-drop-telemetry",
        [:eda, :gateway, :event_dropped],
        fn _event, measurements, metadata, _config ->
          send(test_pid, {:telemetry_drop, measurements, metadata})
        end,
        nil
      )

      on_exit(fn ->
        :telemetry.detach("test-drop-telemetry")
      end)

      Events.dispatch("GUILD_CREATE", %{"id" => "123"})

      assert_receive {:telemetry_drop, %{count: 1}, %{event_type: "GUILD_CREATE"}}, 500
    end
  end

  # A killed handler never reaches the `after` that gives its slot back, so the test does.
  defp release_blocked(pids) do
    Enum.each(pids, &Process.exit(&1, :kill))
    :counters.sub(:persistent_term.get(:eda_event_task_counter), 1, length(pids))
  end

  defp wait_until(condition, attempts \\ 200) do
    cond do
      condition.() -> :ok
      attempts == 0 -> flunk("handlers of a previous test are still running after 2 s")
      true -> Process.sleep(10) && wait_until(condition, attempts - 1)
    end
  end

  # Test consumers

  defmodule EchoConsumer do
    def handle_event(event) do
      send(:task_supervisor_test, {:event, event})
    end
  end

  defmodule BlockingConsumer do
    def handle_event(_event) do
      send(:task_supervisor_test, {:blocked, self()})
      Process.sleep(:infinity)
    end
  end

  defmodule ExitingConsumer do
    def handle_event(_event), do: exit(:gone)
  end

  defmodule ThrowingConsumer do
    def handle_event(_event), do: throw(:thrown)
  end

  defmodule CrashingConsumer do
    def handle_event(_event) do
      raise "intentional crash"
    end
  end
end
