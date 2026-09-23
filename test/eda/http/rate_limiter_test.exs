defmodule EDA.HTTP.RateLimiterTest do
  use ExUnit.Case

  alias EDA.HTTP.RateLimiter

  # The RateLimiter is a single GenServer shared by the whole suite, and its global
  # budget (50 requests per 1s window) is spent by the ~1300 other tests. When it is
  # exhausted, handle_call({:acquire, ..}) takes the {:wait, delay} branch: the caller
  # is queued, the :acquire telemetry never fires, and timing assertions pick up a
  # full window of delay. Every test here assumes a fresh budget, so give it one.
  # Reading the defaults off a fresh struct avoids duplicating @global_limit.
  setup do
    defaults = %RateLimiter{}

    :sys.replace_state(RateLimiter, fn state ->
      %{state | global_remaining: defaults.global_remaining, global_blocked_until: nil}
    end)

    :ok
  end

  describe "queue/4 basic" do
    test "single request executes immediately" do
      result = RateLimiter.queue(:get, "/test/basic", fn -> {:ok, "done"} end)
      assert result == {:ok, "done"}
    end

    test "returns the result of the function" do
      result = RateLimiter.queue(:get, "/test/result", fn -> {:ok, %{"id" => "1"}} end)
      assert result == {:ok, %{"id" => "1"}}
    end
  end

  describe "parallel execution" do
    test "different buckets execute in parallel" do
      start = System.monotonic_time(:millisecond)

      tasks =
        for i <- 1..5 do
          Task.async(fn ->
            RateLimiter.queue(:get, "/channels/#{i}0000000000000000#{i}/messages", fn ->
              Process.sleep(50)
              {:ok, i}
            end)
          end)
        end

      results = Task.await_many(tasks, 5000)
      elapsed = System.monotonic_time(:millisecond) - start

      assert length(results) == 5

      assert Enum.all?(results, fn
               {:ok, _} -> true
               _ -> false
             end)

      # Parallel should be much faster than sequential (5 * 50ms = 250ms)
      assert elapsed < 200
    end
  end

  describe "bucket exhaustion via headers" do
    test "bucket with remaining=0 delays next request" do
      bucket = "/channels/11111111111111111/messages"

      # First request succeeds and reports exhausted bucket
      RateLimiter.queue(:get, bucket, fn ->
        RateLimiter.report_headers(
          EDA.HTTP.Bucket.key(:get, bucket),
          [
            {"x-ratelimit-remaining", "0"},
            {"x-ratelimit-reset-after", "0.1"},
            {"x-ratelimit-bucket", "test-bucket-exhaust"}
          ]
        )

        {:ok, "first"}
      end)

      # Small delay to let cast process
      Process.sleep(10)

      # Second request should be delayed but still complete
      start = System.monotonic_time(:millisecond)

      result = RateLimiter.queue(:get, bucket, fn -> {:ok, "second"} end)

      elapsed = System.monotonic_time(:millisecond) - start
      assert result == {:ok, "second"}
      # Should have waited ~100ms for the bucket to reset
      assert elapsed >= 50
    end
  end

  describe "Discord bucket hash mapping" do
    test "maps route key to discord bucket hash" do
      bucket = "/channels/22222222222222222/messages"
      bucket_key = EDA.HTTP.Bucket.key(:post, bucket)

      RateLimiter.queue(:post, bucket, fn ->
        RateLimiter.report_headers(bucket_key, [
          {"x-ratelimit-remaining", "4"},
          {"x-ratelimit-reset-after", "5.0"},
          {"x-ratelimit-bucket", "discord-hash-abc123"}
        ])

        {:ok, "mapped"}
      end)

      Process.sleep(10)

      # Verify the mapping worked by checking that another request to same route succeeds
      result = RateLimiter.queue(:post, bucket, fn -> {:ok, "next"} end)
      assert result == {:ok, "next"}
    end
  end

  describe "priority queue" do
    test "urgent requests are served before normal and low" do
      # Exhaust a shared bucket
      shared_bucket = "/guilds/33333333333333333/test"
      shared_key = EDA.HTTP.Bucket.key(:get, shared_bucket)

      # Long enough that the three requests are all queued before it resets, however loaded the
      # suite is: with 0.2 s, the last one (urgent) sometimes arrived after the reset, found the
      # low one already served, and the test failed about one full run in ten.
      RateLimiter.report_headers(shared_key, [
        {"x-ratelimit-remaining", "0"},
        {"x-ratelimit-reset-after", "1.0"},
        {"x-ratelimit-bucket", "priority-test-bucket"}
      ])

      Process.sleep(10)

      order = :counters.new(1, [:write_concurrency])
      results = Agent.start_link(fn -> [] end) |> elem(1)

      # Queue low, normal, and urgent in that order
      t_low =
        Task.async(fn ->
          RateLimiter.queue(
            :get,
            shared_bucket,
            fn ->
              pos = :counters.add(order, 1, 1) || :counters.get(order, 1)
              Agent.update(results, fn list -> list ++ [{:low, pos}] end)
              {:ok, :low}
            end,
            priority: :low
          )
        end)

      t_normal =
        Task.async(fn ->
          RateLimiter.queue(
            :get,
            shared_bucket,
            fn ->
              pos = :counters.add(order, 1, 1) || :counters.get(order, 1)
              Agent.update(results, fn list -> list ++ [{:normal, pos}] end)
              {:ok, :normal}
            end,
            priority: :normal
          )
        end)

      t_urgent =
        Task.async(fn ->
          RateLimiter.queue(
            :get,
            shared_bucket,
            fn ->
              pos = :counters.add(order, 1, 1) || :counters.get(order, 1)
              Agent.update(results, fn list -> list ++ [{:urgent, pos}] end)
              {:ok, :urgent}
            end,
            priority: :urgent
          )
        end)

      # Wait until all three are in the queue: that queue, sorted by priority, is what decides the
      # order they are granted in.
      wait_until(fn -> queued_for("priority-test-bucket") == 3 end)
      assert queued_priorities("priority-test-bucket") == [0, 1, 2]

      # Free the bucket and let it drain.

      RateLimiter.report_headers(shared_key, [
        {"x-ratelimit-remaining", "0"},
        {"x-ratelimit-reset-after", "0.01"},
        {"x-ratelimit-bucket", "priority-test-bucket"}
      ])

      Process.sleep(20)
      send(RateLimiter, :process_queue)

      assert [{:ok, :low}, {:ok, :normal}, {:ok, :urgent}] =
               Task.await_many([t_low, t_normal, t_urgent], 5000)

      # Once granted, the three run at the same time, each in its own process, so the order they
      # finish in says nothing about priority; the queue order above does.
      finished = results |> Agent.get(& &1) |> Enum.map(fn {priority, _} -> priority end)
      Agent.stop(results)
      assert Enum.sort(finished) == [:low, :normal, :urgent]
    end
  end

  defp queued_for(discord_bucket) do
    RateLimiter
    |> :sys.get_state()
    |> Map.fetch!(:queue)
    |> Enum.count(fn {_priority, _at, _from, bucket} -> bucket == discord_bucket end)
  end

  # 0 is urgent, 1 normal, 2 low, in the order the queue holds them.
  defp queued_priorities(discord_bucket) do
    RateLimiter
    |> :sys.get_state()
    |> Map.fetch!(:queue)
    |> Enum.filter(fn {_priority, _at, _from, bucket} -> bucket == discord_bucket end)
    |> Enum.map(fn {priority, _at, _from, _bucket} -> priority end)
  end

  defp wait_until(check, attempts \\ 200) do
    cond do
      check.() -> :ok
      attempts == 0 -> flunk("condition never met")
      true -> Process.sleep(5) && wait_until(check, attempts - 1)
    end
  end

  describe "per-major-parameter isolation" do
    test "different guilds use different buckets" do
      bucket1 = "/guilds/44444444444444444/bans"
      bucket2 = "/guilds/55555555555555555/bans"

      key1 = EDA.HTTP.Bucket.key(:get, bucket1)
      key2 = EDA.HTTP.Bucket.key(:get, bucket2)

      assert key1 != key2

      # Exhaust bucket1
      RateLimiter.report_headers(key1, [
        {"x-ratelimit-remaining", "0"},
        {"x-ratelimit-reset-after", "10.0"}
      ])

      Process.sleep(10)

      # bucket2 should still work immediately
      start = System.monotonic_time(:millisecond)

      result = RateLimiter.queue(:get, bucket2, fn -> {:ok, "guild2"} end)

      elapsed = System.monotonic_time(:millisecond) - start
      assert result == {:ok, "guild2"}
      assert elapsed < 50
    end
  end

  describe "max retries" do
    test "gives up after max retries" do
      result =
        RateLimiter.queue(:get, "/test/max-retry", fn ->
          {:error, {:rate_limited, 10}}
        end)

      assert result == {:error, :max_retries_exceeded}
    end
  end

  describe "global rate limit" do
    test "global 429 blocks all buckets temporarily" do
      bucket_key = EDA.HTTP.Bucket.key(:get, "/test/global-block")
      RateLimiter.report_rate_limited(bucket_key, 100, true)

      Process.sleep(10)

      start = System.monotonic_time(:millisecond)

      result =
        RateLimiter.queue(:get, "/channels/66666666666666666/messages", fn ->
          {:ok, "after-global"}
        end)

      elapsed = System.monotonic_time(:millisecond) - start
      assert result == {:ok, "after-global"}
      # Should have waited for the global block
      assert elapsed >= 50
    end
  end

  describe "telemetry" do
    test "emits acquire telemetry" do
      test_pid = self()

      :telemetry.attach(
        "test-rl-acquire",
        [:eda, :rest, :rate_limiter, :acquire],
        fn _event, measurements, _metadata, _config ->
          send(test_pid, {:acquire_telemetry, measurements})
        end,
        nil
      )

      on_exit(fn -> :telemetry.detach("test-rl-acquire") end)

      RateLimiter.queue(:get, "/test/telemetry-acquire", fn -> {:ok, "ok"} end)

      # Generous on purpose: what is under test is that the event fires with
      # queue_depth, not how quickly it arrives.
      assert_receive {:acquire_telemetry, %{queue_depth: _}}, 5_000
    end

    test "emits rate_limited telemetry on 429 retry" do
      test_pid = self()
      call_count = :counters.new(1, [])

      :telemetry.attach(
        "test-rl-limited",
        [:eda, :rest, :rate_limiter, :rate_limited],
        fn _event, measurements, _metadata, _config ->
          send(test_pid, {:rl_telemetry, measurements})
        end,
        nil
      )

      on_exit(fn -> :telemetry.detach("test-rl-limited") end)

      RateLimiter.queue(:get, "/test/telemetry-429", fn ->
        :counters.add(call_count, 1, 1)

        if :counters.get(call_count, 1) == 1 do
          {:error, {:rate_limited, 10}}
        else
          {:ok, "recovered"}
        end
      end)

      assert_receive {:rl_telemetry, %{retry_after_ms: 10}}, 5_000
    end
  end
end
