defmodule EDA.CollectorTest do
  use ExUnit.Case

  alias EDA.Collector

  describe "await/3" do
    test "collects a single matching event" do
      task =
        Task.async(fn ->
          Collector.await(:MESSAGE_CREATE, fn msg -> msg.content == "hello" end, timeout: 5_000)
        end)

      Process.sleep(20)

      Collector.notify(:MESSAGE_CREATE, %{content: "hello", author: "alice"})

      assert {:ok, %{content: "hello"}} = Task.await(task)
    end

    test "ignores events that don't match the filter" do
      task =
        Task.async(fn ->
          Collector.await(:MESSAGE_CREATE, fn msg -> msg.content == "target" end, timeout: 500)
        end)

      Process.sleep(20)

      Collector.notify(:MESSAGE_CREATE, %{content: "wrong"})
      Collector.notify(:MESSAGE_CREATE, %{content: "also_wrong"})

      assert {:error, :timeout} = Task.await(task)
    end

    test "ignores events of different type" do
      task =
        Task.async(fn ->
          Collector.await(:MESSAGE_CREATE, fn _msg -> true end, timeout: 500)
        end)

      Process.sleep(20)

      Collector.notify(:GUILD_CREATE, %{id: "123"})
      Collector.notify(:MESSAGE_REACTION_ADD, %{emoji: "👍"})

      assert {:error, :timeout} = Task.await(task)
    end

    test "returns timeout when no events arrive" do
      result =
        Collector.await(:MESSAGE_CREATE, fn _msg -> true end, timeout: 100)

      assert result == {:error, :timeout}
    end

    test "collects multiple events with max option" do
      task =
        Task.async(fn ->
          Collector.await(:MESSAGE_CREATE, fn _msg -> true end, max: 3, timeout: 5_000)
        end)

      Process.sleep(20)

      Collector.notify(:MESSAGE_CREATE, %{content: "first"})
      Collector.notify(:MESSAGE_CREATE, %{content: "second"})
      Collector.notify(:MESSAGE_CREATE, %{content: "third"})

      assert {:ok, events} = Task.await(task)
      assert length(events) == 3
      assert [%{content: "first"}, %{content: "second"}, %{content: "third"}] = events
    end

    test "multiple concurrent collectors with different filters" do
      task_a =
        Task.async(fn ->
          Collector.await(:MESSAGE_CREATE, fn msg -> msg.channel == "a" end, timeout: 5_000)
        end)

      task_b =
        Task.async(fn ->
          Collector.await(:MESSAGE_CREATE, fn msg -> msg.channel == "b" end, timeout: 5_000)
        end)

      Process.sleep(20)

      Collector.notify(:MESSAGE_CREATE, %{channel: "b", content: "for_b"})
      Collector.notify(:MESSAGE_CREATE, %{channel: "a", content: "for_a"})

      assert {:ok, %{channel: "a", content: "for_a"}} = Task.await(task_a)
      assert {:ok, %{channel: "b", content: "for_b"}} = Task.await(task_b)
    end

    test "filter crash is treated as non-match" do
      task =
        Task.async(fn ->
          Collector.await(:MESSAGE_CREATE, fn msg -> msg.nonexistent.field == "boom" end,
            timeout: 500
          )
        end)

      Process.sleep(20)

      Collector.notify(:MESSAGE_CREATE, %{content: "safe"})

      assert {:error, :timeout} = Task.await(task)
    end

    test "collector is cleaned up after timeout" do
      Collector.await(:MESSAGE_CREATE, fn _msg -> true end, timeout: 50)
      Process.sleep(100)

      # Sending an event after timeout should not cause errors
      Collector.notify(:MESSAGE_CREATE, %{content: "late"})
      Process.sleep(20)
    end

    test "listens to multiple event types" do
      task =
        Task.async(fn ->
          Collector.await([:MESSAGE_CREATE, :MESSAGE_UPDATE], fn _e -> true end, timeout: 5_000)
        end)

      Process.sleep(20)

      Collector.notify(:MESSAGE_UPDATE, %{id: "1", content: "edited"})

      assert {:ok, %{id: "1", content: "edited"}} = Task.await(task)
    end
  end

  describe "convenience functions" do
    test "EDA.await_message/2 delegates to Collector" do
      task =
        Task.async(fn ->
          EDA.await_message(fn msg -> msg.content == "hi" end, timeout: 5_000)
        end)

      Process.sleep(20)

      Collector.notify(:MESSAGE_CREATE, %{content: "hi"})

      assert {:ok, %{content: "hi"}} = Task.await(task)
    end

    test "EDA.await_reaction/2 delegates to Collector" do
      task =
        Task.async(fn ->
          EDA.await_reaction(fn r -> r.emoji == "👍" end, timeout: 5_000)
        end)

      Process.sleep(20)

      Collector.notify(:MESSAGE_REACTION_ADD, %{emoji: "👍", message_id: "1"})

      assert {:ok, %{emoji: "👍"}} = Task.await(task)
    end

    test "EDA.await_component/2 delegates to Collector" do
      task =
        Task.async(fn ->
          EDA.await_component(fn i -> i.custom_id == "btn_ok" end, timeout: 5_000)
        end)

      Process.sleep(20)

      Collector.notify(:INTERACTION_CREATE, %{custom_id: "btn_ok", type: 3})

      assert {:ok, %{custom_id: "btn_ok"}} = Task.await(task)
    end
  end
end
