defmodule EDA.HTTP.RateLimiter do
  @moduledoc """
  Concurrent rate limiter for Discord REST API.

  The GenServer acts as a coordinator — it never executes HTTP requests itself.
  It manages bucket state, a priority queue, and global rate limit tracking.
  Callers block on `GenServer.call` until the coordinator replies `:ok`,
  then execute the HTTP request in their own process (parallel).

  ## Priority levels

  - `:urgent` (0) — bans, kicks, bulk-ban
  - `:normal` (1) — messages, edits (default)
  - `:low` (2) — reads, gets
  """

  use GenServer

  @global_limit 50
  @global_window_ms 1000
  @max_retries 5

  defstruct buckets: %{},
            route_to_discord: %{},
            global_remaining: @global_limit,
            global_blocked_until: nil,
            queue: []

  # Client API

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %__MODULE__{}, name: __MODULE__)
  end

  @doc """
  Queues a request and executes `fun` when the rate limit allows.

  The caller blocks until it receives permission, then `fun.()` runs
  in the caller's process. Handles 429 retries automatically.

  ## Options

  - `:priority` — `:urgent`, `:normal` (default), or `:low`
  """
  @spec queue(atom(), String.t(), (-> term()), keyword()) :: term()
  def queue(method, path, fun, opts \\ []) do
    bucket = EDA.HTTP.Bucket.key(method, path)
    priority = priority_value(opts[:priority] || :normal)

    acquire(bucket, priority)
    execute_with_retry(bucket, fun, 0)
  end

  @doc """
  Reports response headers to update bucket state.
  """
  @spec report_headers(String.t(), [{String.t(), String.t()}]) :: :ok
  def report_headers(bucket, headers) do
    GenServer.cast(__MODULE__, {:headers, bucket, headers})
  end

  @doc """
  Reports a 429 rate limit response.
  """
  @spec report_rate_limited(String.t(), integer(), boolean()) :: :ok
  def report_rate_limited(bucket, retry_after_ms, global?) do
    GenServer.cast(__MODULE__, {:rate_limited, bucket, retry_after_ms, global?})
  end

  # Private client helpers

  defp acquire(bucket, priority) do
    GenServer.call(__MODULE__, {:acquire, bucket, priority}, :infinity)
  end

  defp execute_with_retry(_bucket, _fun, retries) when retries >= @max_retries do
    {:error, :max_retries_exceeded}
  end

  defp execute_with_retry(bucket, fun, retries) do
    result = fun.()

    case result do
      {:error, {:rate_limited, retry_after}} ->
        report_rate_limited(bucket, retry_after, false)

        :telemetry.execute(
          [:eda, :rest, :rate_limiter, :rate_limited],
          %{retry_after_ms: retry_after},
          %{bucket: bucket, attempt: retries + 1}
        )

        Process.sleep(retry_after)
        acquire(bucket, 0)
        execute_with_retry(bucket, fun, retries + 1)

      other ->
        other
    end
  end

  defp priority_value(:urgent), do: 0
  defp priority_value(:normal), do: 1
  defp priority_value(:low), do: 2

  # Server Callbacks

  @impl true
  def init(state) do
    schedule_global_reset()
    {:ok, state}
  end

  @impl true
  def handle_call({:acquire, bucket, priority}, from, state) do
    discord_bucket = Map.get(state.route_to_discord, bucket, bucket)

    case can_request?(state, discord_bucket) do
      :ok ->
        state = decrement_global(state)

        :telemetry.execute(
          [:eda, :rest, :rate_limiter, :acquire],
          %{queue_depth: length(state.queue)},
          %{bucket: bucket}
        )

        {:reply, :ok, state}

      {:wait, delay} ->
        entry = {priority, System.monotonic_time(:millisecond), from, discord_bucket}
        new_queue = insert_by_priority(state.queue, entry)
        schedule_process_queue(delay)

        :telemetry.execute(
          [:eda, :rest, :rate_limiter, :queued],
          %{queue_depth: length(new_queue), delay_ms: delay},
          %{bucket: bucket}
        )

        {:noreply, %{state | queue: new_queue}}
    end
  end

  @impl true
  def handle_cast({:headers, bucket, headers}, state) do
    remaining = get_header_int(headers, "x-ratelimit-remaining")
    reset_after = get_header_float(headers, "x-ratelimit-reset-after")
    discord_hash = get_header(headers, "x-ratelimit-bucket")

    state =
      if remaining && reset_after do
        apply_rate_limit_headers(state, bucket, remaining, reset_after, discord_hash)
      else
        state
      end

    {:noreply, state}
  end

  def handle_cast({:rate_limited, _bucket, retry_after_ms, true}, state) do
    now = System.monotonic_time(:millisecond)

    {:noreply, %{state | global_blocked_until: now + retry_after_ms}}
  end

  def handle_cast({:rate_limited, bucket, retry_after_ms, false}, state) do
    now = System.monotonic_time(:millisecond)
    discord_bucket = Map.get(state.route_to_discord, bucket, bucket)

    bucket_info = %{remaining: 0, reset_at: now + retry_after_ms}
    new_buckets = Map.put(state.buckets, discord_bucket, bucket_info)

    {:noreply, %{state | buckets: new_buckets}}
  end

  @impl true
  def handle_info(:reset_global, state) do
    schedule_global_reset()
    {:noreply, %{state | global_remaining: @global_limit}}
  end

  def handle_info(:process_queue, state) do
    {:noreply, process_queue(state)}
  end

  def handle_info(_msg, state), do: {:noreply, state}

  # Private server helpers

  defp apply_rate_limit_headers(state, bucket, remaining, reset_after, discord_hash) do
    now = System.monotonic_time(:millisecond)
    reset_at = now + trunc(reset_after * 1000)
    discord_key = discord_hash || bucket
    bucket_info = %{remaining: remaining, reset_at: reset_at}

    state = put_in(state, [Access.key(:buckets), discord_key], bucket_info)

    if discord_hash do
      put_in(state, [Access.key(:route_to_discord), bucket], discord_hash)
    else
      state
    end
  end

  defp can_request?(state, bucket) do
    now = System.monotonic_time(:millisecond)

    cond do
      state.global_blocked_until && state.global_blocked_until > now ->
        {:wait, state.global_blocked_until - now}

      state.global_remaining <= 0 ->
        {:wait, @global_window_ms}

      bucket_exhausted?(state, bucket, now) ->
        reset_at = get_in(state.buckets, [bucket, :reset_at]) || now + 1000
        {:wait, max(1, reset_at - now)}

      true ->
        :ok
    end
  end

  defp bucket_exhausted?(state, bucket, now) do
    case Map.get(state.buckets, bucket) do
      nil -> false
      %{remaining: remaining, reset_at: reset_at} -> remaining <= 0 and reset_at > now
    end
  end

  defp decrement_global(state) do
    %{state | global_remaining: state.global_remaining - 1}
  end

  defp process_queue(%{queue: []} = state), do: state

  defp process_queue(%{queue: [{_prio, _ts, from, bucket} | rest]} = state) do
    case can_request?(state, bucket) do
      :ok ->
        state = decrement_global(%{state | queue: rest})
        GenServer.reply(from, :ok)
        process_queue(state)

      {:wait, delay} ->
        schedule_process_queue(delay)
        state
    end
  end

  defp insert_by_priority(queue, {prio, _, _, _} = entry) do
    {before, after_} = Enum.split_while(queue, fn {p, _, _, _} -> p <= prio end)
    before ++ [entry] ++ after_
  end

  defp schedule_global_reset do
    Process.send_after(self(), :reset_global, @global_window_ms)
  end

  defp schedule_process_queue(delay) do
    Process.send_after(self(), :process_queue, max(1, trunc(delay)))
  end

  defp get_header(headers, key) do
    case List.keyfind(headers, key, 0) || List.keyfind(headers, String.upcase(key), 0) do
      {_, value} -> value
      nil -> nil
    end
  end

  defp get_header_int(headers, key) do
    case get_header(headers, key) do
      nil -> nil
      val -> String.to_integer(val)
    end
  end

  defp get_header_float(headers, key) do
    case get_header(headers, key) do
      nil -> nil
      val -> String.to_float(val)
    end
  end
end
