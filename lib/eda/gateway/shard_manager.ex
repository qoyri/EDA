defmodule EDA.Gateway.ShardManager do
  @moduledoc """
  Orchestrates the lifecycle of all gateway shards.

  Inspired by JDA's `DefaultShardManager` but built on OTP primitives:
  - Fetches `/gateway/bot` for recommended shard count and `max_concurrency`
  - Launches shards via `DynamicSupervisor` with staggered timing
  - Monitors shards and auto-reconnects with exponential backoff + jitter
  - Stores `total_shards` in `:persistent_term` for O(1) guild→shard routing

  ## Configuration

      config :eda, shards: :auto           # use Discord's recommended count (default)
      config :eda, shards: 4               # fixed 4 shards (0..3)
      config :eda, shards: {0..1, 4}       # this node handles shards 0,1 out of 4 total
  """

  use GenServer

  require Logger

  @max_backoff 30_000
  @base_backoff 1_000

  defstruct [
    :token,
    :gateway_url,
    :compression,
    :total_shards,
    :max_concurrency,
    shard_ids: [],
    launched: MapSet.new(),
    queue: :queue.new(),
    statuses: %{},
    attempts: %{},
    session_limit_remaining: nil,
    session_limit_reset_at: nil
  ]

  # Public API

  @doc """
  Computes which shard owns a guild. Pure function — no GenServer call.

  Uses `:persistent_term` for O(1) access to `total_shards`.
  """
  @spec shard_for_guild(integer() | String.t()) :: non_neg_integer()
  def shard_for_guild(guild_id) when is_integer(guild_id) do
    total = :persistent_term.get(:eda_total_shards, 1)
    rem(Bitwise.bsr(guild_id, 22), total)
  end

  def shard_for_guild(guild_id) when is_binary(guild_id) do
    guild_id |> String.to_integer() |> shard_for_guild()
  end

  @doc "Returns the total number of shards."
  @spec total_shards() :: non_neg_integer()
  def total_shards do
    :persistent_term.get(:eda_total_shards, 1)
  end

  @doc "Returns the number of launched shards."
  @spec shard_count() :: non_neg_integer()
  def shard_count do
    GenServer.call(__MODULE__, :shard_count)
  end

  @doc "Returns the status of a shard."
  @spec shard_status(non_neg_integer()) :: :launching | :connected | :disconnected | nil
  def shard_status(shard_id) do
    GenServer.call(__MODULE__, {:shard_status, shard_id})
  end

  @doc "Returns a map with shard statuses and session limit info."
  @spec status() :: map()
  def status do
    GenServer.call(__MODULE__, :status)
  end

  @doc "Forces a shard to reconnect."
  @spec reconnect(non_neg_integer()) :: :ok
  def reconnect(shard_id) do
    GenServer.cast(__MODULE__, {:reconnect, shard_id})
  end

  @doc false
  def shard_connected(shard_id) do
    GenServer.cast(__MODULE__, {:shard_connected, shard_id})
  end

  # Server

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    token = Keyword.fetch!(opts, :token)
    send(self(), :connect)
    {:ok, %__MODULE__{token: token}}
  end

  @impl true
  def handle_info(:connect, state) do
    case EDA.API.Gateway.bot() do
      {:ok, data} ->
        encoding = EDA.Gateway.Encoding.module()
        # Chosen once, so the URL and every shard's decompressor agree.
        compression = EDA.Gateway.Compression.module()

        gateway_url =
          data["url"] <>
            "/?v=10&encoding=#{encoding.url_encoding()}" <>
            "&compress=#{EDA.Gateway.Compression.url_param(compression)}"

        recommended = data["shards"] || 1
        max_concurrency = get_in(data, ["session_start_limit", "max_concurrency"]) || 1

        {shard_ids, total} = resolve_shards(EDA.shard_config(), recommended)

        :persistent_term.put(:eda_total_shards, total)

        # Track session start limits
        session_limit = data["session_start_limit"] || %{}
        remaining = session_limit["remaining"] || 1000
        reset_after = session_limit["reset_after"] || 0

        Logger.info(
          "Gateway: #{length(shard_ids)} shard(s) of #{total} total " <>
            "(max_concurrency=#{max_concurrency}, session_starts_remaining=#{remaining})"
        )

        new_state = %{
          state
          | gateway_url: gateway_url,
            compression: compression,
            total_shards: total,
            max_concurrency: max_concurrency,
            shard_ids: shard_ids,
            session_limit_remaining: remaining,
            session_limit_reset_at: System.monotonic_time(:millisecond) + reset_after
        }

        maybe_start_shards(new_state, shard_ids, remaining, reset_after)

      {:error, reason} ->
        Logger.error("Failed to fetch /gateway/bot: #{inspect(reason)}, retrying in 5s")
        Process.send_after(self(), :connect, 5_000)
        {:noreply, state}
    end
  end

  def handle_info(:process_queue, state) do
    case :queue.out(state.queue) do
      {{:value, shard_id}, rest} ->
        new_state = launch_shard(shard_id, %{state | queue: rest})

        # Schedule next shard launch respecting max_concurrency
        delay = div(5_500, state.max_concurrency)
        Process.send_after(self(), :process_queue, delay)

        {:noreply, new_state}

      {:empty, _} ->
        {:noreply, state}
    end
  end

  def handle_info({:DOWN, _ref, :process, pid, reason}, state) do
    case find_shard_by_pid(pid) do
      nil ->
        {:noreply, state}

      shard_id ->
        Logger.warning("[Shard #{shard_id}/#{state.total_shards}] Down: #{inspect(reason)}")

        attempt = Map.get(state.attempts, shard_id, 0) + 1
        delay = reconnect_delay(attempt)

        Logger.info(
          "[Shard #{shard_id}/#{state.total_shards}] Reconnecting in #{delay}ms (attempt #{attempt})"
        )

        Process.send_after(self(), {:relaunch, shard_id}, delay)

        new_state = %{
          state
          | launched: MapSet.delete(state.launched, shard_id),
            statuses: Map.put(state.statuses, shard_id, :disconnected),
            attempts: Map.put(state.attempts, shard_id, attempt)
        }

        {:noreply, new_state}
    end
  end

  def handle_info({:relaunch, shard_id}, state) do
    new_state = launch_shard(shard_id, state)
    {:noreply, new_state}
  end

  def handle_info(_msg, state), do: {:noreply, state}

  @impl true
  def handle_call(:shard_count, _from, state) do
    {:reply, MapSet.size(state.launched), state}
  end

  def handle_call({:shard_status, shard_id}, _from, state) do
    {:reply, Map.get(state.statuses, shard_id), state}
  end

  def handle_call(:status, _from, state) do
    info = %{
      statuses: state.statuses,
      launched: MapSet.size(state.launched),
      total_shards: state.total_shards,
      session_limit_remaining: state.session_limit_remaining,
      session_limit_reset_at: state.session_limit_reset_at
    }

    {:reply, info, state}
  end

  @impl true
  def handle_cast({:shard_connected, shard_id}, state) do
    Logger.info("[Shard #{shard_id}/#{state.total_shards}] Connected")

    new_state = %{
      state
      | statuses: Map.put(state.statuses, shard_id, :connected),
        attempts: Map.delete(state.attempts, shard_id),
        session_limit_remaining: max((state.session_limit_remaining || 1000) - 1, 0)
    }

    {:noreply, new_state}
  end

  def handle_cast({:reconnect, shard_id}, state) do
    case Registry.lookup(EDA.Gateway.Registry, shard_id) do
      [{pid, _}] ->
        Process.exit(pid, :reconnect)
        {:noreply, state}

      [] ->
        # Not running, enqueue for launch
        queue = :queue.in(shard_id, state.queue)
        send(self(), :process_queue)
        {:noreply, %{state | queue: queue}}
    end
  end

  # Internal

  defp launch_shard(shard_id, state) do
    opts = [
      token: state.token,
      shard: {shard_id, state.total_shards},
      gateway_url: state.gateway_url,
      compression: state.compression
    ]

    case DynamicSupervisor.start_child(
           EDA.Gateway.DynamicSupervisor,
           {EDA.Gateway.Connection, opts}
         ) do
      {:ok, pid} ->
        Process.monitor(pid)

        %{
          state
          | launched: MapSet.put(state.launched, shard_id),
            statuses: Map.put(state.statuses, shard_id, :launching)
        }

      {:error, reason} ->
        Logger.error(
          "[Shard #{shard_id}/#{state.total_shards}] Failed to start: #{inspect(reason)}"
        )

        # Re-enqueue with delay
        Process.send_after(self(), {:relaunch, shard_id}, 5_000)
        state
    end
  end

  defp maybe_start_shards(state, shard_ids, remaining, reset_after) do
    if remaining < length(shard_ids) do
      Logger.error(
        "Only #{remaining} session starts remaining, need #{length(shard_ids)}. " <>
          "Waiting #{reset_after}ms for reset."
      )

      Process.send_after(self(), :connect, reset_after + 1_000)
      {:noreply, state}
    else
      queue =
        Enum.reduce(shard_ids, :queue.new(), fn id, q ->
          :queue.in(id, q)
        end)

      send(self(), :process_queue)
      {:noreply, %{state | queue: queue}}
    end
  end

  defp find_shard_by_pid(pid) do
    case Registry.keys(EDA.Gateway.Registry, pid) do
      [shard_id] -> shard_id
      _ -> nil
    end
  end

  @doc false
  def resolve_shards(:auto, recommended), do: {Enum.to_list(0..(recommended - 1)), recommended}
  def resolve_shards(n, _recommended) when is_integer(n), do: {Enum.to_list(0..(n - 1)), n}

  def resolve_shards({%Range{} = range, total}, _recommended) do
    {Enum.to_list(range), total}
  end

  def resolve_shards({range, total}, _recommended) when is_list(range) do
    {range, total}
  end

  @doc false
  def reconnect_delay(attempt) do
    delay = min(@base_backoff * Bitwise.bsl(1, attempt - 1), @max_backoff)
    delay + :rand.uniform(1_000)
  end
end
