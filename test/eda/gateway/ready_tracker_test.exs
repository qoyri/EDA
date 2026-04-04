defmodule EDA.Gateway.ReadyTrackerTest do
  use ExUnit.Case, async: false

  alias EDA.Gateway.ReadyTracker

  defmodule TestConsumer do
    @behaviour EDA.Consumer

    def handle_event(event) do
      send(:ready_tracker_test, {:event, event})
    end
  end

  setup do
    # Reset persistent_term state
    :persistent_term.put(:eda_globally_ready, false)

    # Reset the existing tracker's internal state and clear ETS
    :ets.delete_all_objects(:eda_pending_guilds)

    # Synchronous state reset — flush any pending GenServer messages first
    _ = :sys.get_state(ReadyTracker)

    :sys.replace_state(ReadyTracker, fn _old ->
      %EDA.Gateway.ReadyTracker{
        pending_counts: %{},
        guild_to_shard: %{},
        ready_shards: MapSet.new(),
        expected_shards: nil,
        waiters: [],
        globally_ready: false,
        timeout_ms: 500,
        shard_timers: %{},
        shard_start_times: %{},
        start_time: System.monotonic_time(:millisecond)
      }
    end)

    # Ensure persistent_term reflects the reset
    :persistent_term.put(:eda_globally_ready, false)

    on_exit(fn ->
      Application.delete_env(:eda, :consumer)
    end)

    :ok
  end

  describe "shard_ready/2 with 0 guilds" do
    test "shard is immediately ready" do
      :persistent_term.put(:eda_total_shards, 1)

      ReadyTracker.shard_ready(0, [])
      Process.sleep(50)

      assert ReadyTracker.ready?()
    end
  end

  describe "shard_ready/2 + guild_loaded/1" do
    test "decrements correctly and becomes ready" do
      :persistent_term.put(:eda_total_shards, 1)

      ReadyTracker.shard_ready(0, ["g1", "g2"])
      Process.sleep(50)

      refute ReadyTracker.ready?()
      assert ReadyTracker.loading?("g1")
      assert ReadyTracker.loading?("g2")

      ReadyTracker.guild_loaded("g1")
      Process.sleep(20)

      refute ReadyTracker.ready?()
      assert ReadyTracker.loading?("g2")
      refute ReadyTracker.loading?("g1")

      ReadyTracker.guild_loaded("g2")
      Process.sleep(50)

      assert ReadyTracker.ready?()
    end
  end

  describe "loading?/1" do
    test "returns true for pending guild" do
      :persistent_term.put(:eda_total_shards, 1)

      ReadyTracker.shard_ready(0, ["g1"])
      Process.sleep(20)

      assert ReadyTracker.loading?("g1")
    end

    test "returns false after guild loaded" do
      :persistent_term.put(:eda_total_shards, 1)

      ReadyTracker.shard_ready(0, ["g1"])
      Process.sleep(20)

      ReadyTracker.guild_loaded("g1")
      Process.sleep(20)

      refute ReadyTracker.loading?("g1")
    end

    test "returns false for unknown guild" do
      refute ReadyTracker.loading?("unknown_guild")
    end
  end

  describe "await_ready/1" do
    test "returns :ok immediately when already ready" do
      :persistent_term.put(:eda_total_shards, 1)

      ReadyTracker.shard_ready(0, [])
      Process.sleep(50)

      assert :ok = ReadyTracker.await_ready(1_000)
    end

    test "blocks then returns :ok when ready" do
      :persistent_term.put(:eda_total_shards, 1)

      ReadyTracker.shard_ready(0, ["g1"])

      task =
        Task.async(fn ->
          ReadyTracker.await_ready(5_000)
        end)

      Process.sleep(50)
      ReadyTracker.guild_loaded("g1")

      assert :ok = Task.await(task, 5_000)
    end

    test "returns {:error, :timeout} on timeout" do
      :persistent_term.put(:eda_total_shards, 2)

      # Only register 1 shard, never complete shard 2
      ReadyTracker.shard_ready(0, [])

      assert {:error, :timeout} = ReadyTracker.await_ready(200)
    end
  end

  describe "ready?/0" do
    test "returns false before ready" do
      refute ReadyTracker.ready?()
    end

    test "returns true after all shards ready" do
      :persistent_term.put(:eda_total_shards, 1)

      ReadyTracker.shard_ready(0, [])
      Process.sleep(50)

      assert ReadyTracker.ready?()
    end
  end

  describe "multi-shard" do
    test "ready only when all shards complete" do
      :persistent_term.put(:eda_total_shards, 2)

      ReadyTracker.shard_ready(0, ["g1"])
      ReadyTracker.shard_ready(1, ["g2"])
      Process.sleep(20)

      refute ReadyTracker.ready?()

      ReadyTracker.guild_loaded("g1")
      Process.sleep(50)

      refute ReadyTracker.ready?()

      ReadyTracker.guild_loaded("g2")
      Process.sleep(50)

      assert ReadyTracker.ready?()
    end
  end

  describe "guild timeout" do
    test "shard becomes ready after timeout with pending guilds" do
      :persistent_term.put(:eda_total_shards, 1)

      # timeout_ms is 500ms from setup
      ReadyTracker.shard_ready(0, ["g1", "g2"])
      Process.sleep(20)

      refute ReadyTracker.ready?()

      # Wait for timeout to fire
      Process.sleep(600)

      assert ReadyTracker.ready?()
      refute ReadyTracker.loading?("g1")
      refute ReadyTracker.loading?("g2")
    end
  end

  describe "status/0" do
    test "returns detailed state" do
      :persistent_term.put(:eda_total_shards, 1)

      ReadyTracker.shard_ready(0, ["g1", "g2"])
      Process.sleep(20)

      status = ReadyTracker.status()
      assert status.globally_ready == false
      assert status.pending_counts[0] == 2
      assert status.expected_shards == 1
    end
  end

  describe "event dispatch integration" do
    test "GUILD_CREATE during loading dispatches GUILD_AVAILABLE" do
      Process.register(self(), :ready_tracker_test)
      Application.put_env(:eda, :consumer, __MODULE__.TestConsumer)
      :persistent_term.put(:eda_total_shards, 1)

      ReadyTracker.shard_ready(0, ["g_avail"])
      Process.sleep(20)

      EDA.Gateway.Events.dispatch("GUILD_CREATE", %{
        "id" => "g_avail",
        "name" => "Test Guild"
      })

      assert_receive {:event, {:GUILD_AVAILABLE, struct}}, 1_000
      assert struct.id == "g_avail"
    end

    test "GUILD_CREATE at runtime dispatches GUILD_CREATE" do
      Process.register(self(), :ready_tracker_test)
      Application.put_env(:eda, :consumer, __MODULE__.TestConsumer)

      EDA.Gateway.Events.dispatch("GUILD_CREATE", %{
        "id" => "g_runtime",
        "name" => "Runtime Guild"
      })

      assert_receive {:event, {:GUILD_CREATE, struct}}, 1_000
      assert struct.id == "g_runtime"
    end

    test "SHARD_READY event is dispatched" do
      Process.register(self(), :ready_tracker_test)
      Application.put_env(:eda, :consumer, __MODULE__.TestConsumer)
      :persistent_term.put(:eda_total_shards, 1)

      ReadyTracker.shard_ready(0, [])

      assert_receive {:event, {:SHARD_READY, %EDA.Event.ShardReady{} = ev}}, 1_000
      assert ev.shard_id == 0
      assert ev.guild_count == 0
    end

    test "ALL_SHARDS_READY event is dispatched" do
      Process.register(self(), :ready_tracker_test)
      Application.put_env(:eda, :consumer, __MODULE__.TestConsumer)
      :persistent_term.put(:eda_total_shards, 1)

      ReadyTracker.shard_ready(0, [])

      assert_receive {:event, {:ALL_SHARDS_READY, %EDA.Event.AllShardsReady{} = ev}}, 1_000
      assert ev.shard_count == 1
      assert ev.guild_count == 0
    end
  end
end
