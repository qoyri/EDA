defmodule EDA.REST.RateLimiter do
  @moduledoc """
  Rate limiter for Discord REST API.

  Tracks rate limits per bucket and queues requests when limits are hit.
  Discord uses a bucket-based rate limiting system where endpoints
  share rate limits based on route patterns.

  ## How it works

  1. Each request is associated with a "bucket" based on its route
  2. The rate limiter tracks remaining calls and reset times per bucket
  3. If a bucket is exhausted, requests are queued until it resets
  4. Global rate limits (50 requests/second) are also tracked
  """

  use GenServer

  require Logger

  @global_limit 50
  @global_window 1000

  defstruct buckets: %{},
            global_remaining: @global_limit,
            global_reset: nil,
            queue: :queue.new()

  # Client API

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %__MODULE__{}, name: __MODULE__)
  end

  @doc """
  Queues a request to be executed when rate limits allow.

  ## Parameters

  - `method` - HTTP method (:get, :post, etc.)
  - `path` - API path
  - `fun` - Function that performs the actual request

  Returns the result of the function.
  """
  @spec queue(atom(), String.t(), (-> term())) :: term()
  def queue(method, path, fun) do
    bucket = get_bucket(path, method)
    GenServer.call(__MODULE__, {:queue, bucket, fun}, :infinity)
  end

  @doc """
  Updates rate limit info after receiving response headers.
  """
  @spec update(String.t(), integer(), integer(), String.t() | nil) :: :ok
  def update(bucket, remaining, reset_after, discord_bucket) do
    GenServer.cast(__MODULE__, {:update, bucket, remaining, reset_after, discord_bucket})
  end

  # Server Callbacks

  @impl true
  def init(state) do
    schedule_global_reset()
    {:ok, state}
  end

  @impl true
  def handle_call({:queue, bucket, fun}, from, state) do
    case can_request?(state, bucket) do
      :ok ->
        # Execute immediately
        state = decrement_limits(state, bucket)
        {:noreply, state, {:continue, {:execute, from, fun}}}

      {:wait, delay} ->
        # Queue the request
        entry = {from, bucket, fun, System.monotonic_time(:millisecond) + delay}
        new_queue = :queue.in(entry, state.queue)
        schedule_process_queue(delay)
        {:noreply, %{state | queue: new_queue}}
    end
  end

  @impl true
  def handle_continue({:execute, from, fun}, state) do
    result = fun.()
    GenServer.reply(from, result)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:update, bucket, remaining, reset_after, discord_bucket}, state) do
    bucket_key = discord_bucket || bucket

    bucket_info = %{
      remaining: remaining,
      reset_at: System.monotonic_time(:millisecond) + reset_after
    }

    new_buckets = Map.put(state.buckets, bucket_key, bucket_info)
    {:noreply, %{state | buckets: new_buckets}}
  end

  @impl true
  def handle_info(:reset_global, state) do
    schedule_global_reset()
    {:noreply, %{state | global_remaining: @global_limit}}
  end

  def handle_info(:process_queue, state) do
    state = process_queue(state)
    {:noreply, state}
  end

  def handle_info(_msg, state), do: {:noreply, state}

  # Private Functions

  defp can_request?(state, bucket) do
    now = System.monotonic_time(:millisecond)

    cond do
      state.global_remaining <= 0 ->
        {:wait, @global_window}

      bucket_exhausted?(state, bucket, now) ->
        reset_at = get_in(state.buckets, [bucket, :reset_at]) || now + 1000
        {:wait, max(0, reset_at - now)}

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

  defp decrement_limits(state, bucket) do
    new_global = state.global_remaining - 1

    new_buckets =
      Map.update(state.buckets, bucket, nil, fn
        nil -> nil
        info -> %{info | remaining: max(0, info.remaining - 1)}
      end)

    %{state | global_remaining: new_global, buckets: new_buckets}
  end

  defp process_queue(state) do
    now = System.monotonic_time(:millisecond)

    case :queue.out(state.queue) do
      {:empty, _} ->
        state

      {{:value, {from, bucket, fun, ready_at}}, rest} when ready_at <= now ->
        case can_request?(state, bucket) do
          :ok ->
            state = decrement_limits(%{state | queue: rest}, bucket)

            Task.start(fn ->
              result = fun.()
              GenServer.reply(from, result)
            end)

            process_queue(state)

          {:wait, delay} ->
            schedule_process_queue(delay)
            state
        end

      {{:value, {_from, _bucket, _fun, ready_at}}, _rest} ->
        schedule_process_queue(ready_at - now)
        state
    end
  end

  defp schedule_global_reset do
    Process.send_after(self(), :reset_global, @global_window)
  end

  defp schedule_process_queue(delay) do
    Process.send_after(self(), :process_queue, max(1, delay))
  end

  @doc false
  def get_bucket(path, method) do
    # Extract major parameters (guild_id, channel_id, webhook_id)
    # These share rate limits
    path
    |> String.replace(~r/\/\d{17,19}/, "/:id")
    |> then(fn normalized ->
      # DELETE on messages has its own bucket
      if method == :delete and String.contains?(normalized, "/messages/") do
        "DELETE:" <> normalized
      else
        normalized
      end
    end)
  end
end
