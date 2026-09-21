defmodule EDA.Gateway.ReadyTracker do
  @moduledoc """
  Tracks guild loading progress after READY to distinguish startup loads from runtime joins.

  When Discord sends READY, it includes guild stubs (`unavailable: true`). Full guild data
  arrives via subsequent GUILD_CREATE events. This GenServer tracks which guilds are still
  loading and fires `SHARD_READY` / `ALL_SHARDS_READY` events when loading completes.

  Uses an ETS table (`:eda_pending_guilds`) for O(1) lookups in the hot path
  and `:persistent_term` for the global ready flag.
  """

  use GenServer

  require Logger

  @ets_table :eda_pending_guilds

  defstruct pending_counts: %{},
            guild_to_shard: %{},
            ready_shards: MapSet.new(),
            down_shards: MapSet.new(),
            expected_shards: nil,
            waiters: [],
            globally_ready: false,
            timeout_ms: 60_000,
            shard_timers: %{},
            shard_start_times: %{},
            start_time: nil

  # ── Public API ──────────────────────────────────────────────────────

  @doc "Starts the ReadyTracker."
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Registers pending guilds for a shard after receiving READY.

  Called by `EDA.Gateway.Connection` when a READY payload arrives.
  """
  @spec shard_ready(non_neg_integer(), [String.t()]) :: :ok
  def shard_ready(shard_id, guild_ids) do
    GenServer.cast(__MODULE__, {:shard_ready, shard_id, guild_ids})
  end

  @doc """
  Marks a guild as loaded (received its GUILD_CREATE).

  Called by `EDA.Gateway.Events` when a startup GUILD_CREATE arrives.
  """
  @spec guild_loaded(String.t()) :: :ok
  def guild_loaded(guild_id) do
    GenServer.cast(__MODULE__, {:guild_loaded, guild_id})
  end

  @doc """
  Returns `true` if the guild is still loading (pending GUILD_CREATE).

  Reads directly from ETS — no GenServer call, O(1).
  """
  @spec loading?(String.t()) :: boolean()
  def loading?(guild_id) do
    try do
      :ets.member(@ets_table, guild_id)
    rescue
      ArgumentError -> false
    end
  end

  @doc """
  Blocks until all shards have finished loading their guilds.

  Returns `:ok` when the bot is fully ready, or `{:error, :timeout}` if the
  timeout expires. Uses OTP's native `GenServer.call` suspension — no scheduler
  is blocked.

  If the bot is already ready, returns `:ok` immediately.

  ## Examples

      EDA.await_ready()
      EDA.await_ready(30_000)
  """
  @spec await_ready(timeout()) :: :ok | {:error, :timeout}
  def await_ready(timeout \\ 60_000) do
    try do
      GenServer.call(__MODULE__, :await_ready, timeout)
    catch
      :exit, {:timeout, _} -> {:error, :timeout}
    end
  end

  @doc """
  Reports that a shard's gateway connection closed.

  Called by `EDA.Gateway.Connection` on every disconnect. A shard that had finished loading
  stops counting as ready until it resumes or completes a fresh READY, so `ready?/0` stops
  answering `true` for a bot that has lost its gateway.
  """
  @spec shard_disconnected(non_neg_integer()) :: :ok
  def shard_disconnected(shard_id) do
    GenServer.cast(__MODULE__, {:shard_disconnected, shard_id})
  end

  @doc """
  Reports that a shard resumed its session.

  A resume carries on the same session, so Discord sends RESUMED rather than READY and does
  not reload the guilds. A shard that was ready before the disconnect is ready again at
  once. `SHARD_READY` and `ALL_SHARDS_READY` are not dispatched a second time, because from
  the consumer's side nothing restarted.
  """
  @spec shard_resumed(non_neg_integer()) :: :ok
  def shard_resumed(shard_id) do
    GenServer.cast(__MODULE__, {:shard_resumed, shard_id})
  end

  @doc """
  Returns `true` if every shard is connected and has finished loading its guilds.

  Goes back to `false` while any shard's gateway connection is down, and returns to `true`
  once it resumes or completes a fresh READY — so it is safe to use as a readiness check.
  REST calls do not depend on the gateway and keep working while this is `false`; events,
  voice and member chunking do not.

  Non-blocking — reads from `:persistent_term` (O(1)).
  """
  @spec ready?() :: boolean()
  def ready? do
    :persistent_term.get(:eda_globally_ready, false)
  end

  @doc """
  Returns detailed status information about the loading state.

  ## Return value

  A map with keys:

    - `:globally_ready` — whether all shards are ready
    - `:ready_shards` — set of shard IDs that finished loading
    - `:expected_shards` — total number of shards expected
    - `:pending_counts` — map of shard_id => remaining guild count
  """
  @spec status() :: map()
  def status do
    GenServer.call(__MODULE__, :status)
  end

  # ── GenServer callbacks ─────────────────────────────────────────────

  @impl true
  def init(_opts) do
    :ets.new(@ets_table, [:set, :public, :named_table, read_concurrency: true])
    :persistent_term.put(:eda_globally_ready, false)

    timeout_ms = Application.get_env(:eda, :ready_timeout, 60_000)

    {:ok, %__MODULE__{timeout_ms: timeout_ms, start_time: System.monotonic_time(:millisecond)},
     {:continue, :resolve_expected_shards}}
  end

  @impl true
  def handle_continue(:resolve_expected_shards, state) do
    expected =
      try do
        :persistent_term.get(:eda_total_shards)
      rescue
        ArgumentError -> nil
      end

    {:noreply, %{state | expected_shards: expected}}
  end

  @impl true
  def handle_cast({:shard_disconnected, shard_id}, state) do
    was_ready = MapSet.member?(state.ready_shards, shard_id)

    if state.globally_ready do
      :persistent_term.put(:eda_globally_ready, false)
      Logger.info("[ReadyTracker] Shard #{shard_id} disconnected — no longer ready")
    end

    {:noreply,
     %{
       state
       | ready_shards: MapSet.delete(state.ready_shards, shard_id),
         down_shards:
           if(was_ready, do: MapSet.put(state.down_shards, shard_id), else: state.down_shards),
         globally_ready: false
     }}
  end

  # A shard that had not finished loading when it dropped just carries on loading: Discord
  # replays the missed GUILD_CREATEs after a resume, and they are counted as before.
  def handle_cast({:shard_resumed, shard_id}, state) do
    if MapSet.member?(state.down_shards, shard_id) do
      state = %{
        state
        | ready_shards: MapSet.put(state.ready_shards, shard_id),
          down_shards: MapSet.delete(state.down_shards, shard_id)
      }

      {:noreply, maybe_restore_ready(state)}
    else
      {:noreply, state}
    end
  end

  def handle_cast({:shard_ready, shard_id, guild_ids}, state) do
    state = %{state | down_shards: MapSet.delete(state.down_shards, shard_id)}

    # Refresh expected_shards if not yet known
    state = maybe_refresh_expected(state)

    # Insert all guild IDs into ETS
    for gid <- guild_ids do
      :ets.insert(@ets_table, {gid})
    end

    # Build guild_to_shard mappings
    new_g2s =
      Enum.reduce(guild_ids, state.guild_to_shard, fn gid, acc ->
        Map.put(acc, gid, shard_id)
      end)

    count = length(guild_ids)

    new_state = %{
      state
      | pending_counts: Map.put(state.pending_counts, shard_id, count),
        guild_to_shard: new_g2s,
        shard_start_times:
          Map.put(state.shard_start_times, shard_id, System.monotonic_time(:millisecond))
    }

    if count == 0 do
      # Shard has no guilds — immediately ready
      {:noreply, mark_shard_ready(shard_id, new_state)}
    else
      # Schedule timeout
      timer = Process.send_after(self(), {:guild_timeout, shard_id}, state.timeout_ms)
      {:noreply, %{new_state | shard_timers: Map.put(new_state.shard_timers, shard_id, timer)}}
    end
  end

  def handle_cast({:guild_loaded, guild_id}, state) do
    case Map.fetch(state.guild_to_shard, guild_id) do
      {:ok, shard_id} ->
        :ets.delete(@ets_table, guild_id)

        new_g2s = Map.delete(state.guild_to_shard, guild_id)
        new_count = Map.get(state.pending_counts, shard_id, 1) - 1
        new_pending = Map.put(state.pending_counts, shard_id, new_count)

        new_state = %{state | guild_to_shard: new_g2s, pending_counts: new_pending}

        if new_count <= 0 do
          {:noreply, mark_shard_ready(shard_id, new_state)}
        else
          {:noreply, new_state}
        end

      :error ->
        # Guild not tracked (could be a runtime GUILD_CREATE)
        {:noreply, state}
    end
  end

  @impl true
  def handle_call(:await_ready, _from, %{globally_ready: true} = state) do
    {:reply, :ok, state}
  end

  def handle_call(:await_ready, from, state) do
    {:noreply, %{state | waiters: [from | state.waiters]}}
  end

  def handle_call(:status, _from, state) do
    info = %{
      globally_ready: state.globally_ready,
      ready_shards: state.ready_shards,
      expected_shards: state.expected_shards,
      pending_counts: state.pending_counts
    }

    {:reply, info, state}
  end

  @impl true
  def handle_info({:guild_timeout, shard_id}, state) do
    if MapSet.member?(state.ready_shards, shard_id) do
      {:noreply, state}
    else
      remaining =
        state.guild_to_shard
        |> Enum.filter(fn {_gid, sid} -> sid == shard_id end)
        |> Enum.map(fn {gid, _} -> gid end)

      Logger.warning(
        "[ReadyTracker] Shard #{shard_id} timed out with #{length(remaining)} guild(s) still pending"
      )

      # Clean up remaining guilds from ETS and state
      for gid <- remaining, do: :ets.delete(@ets_table, gid)

      new_g2s =
        Enum.reduce(remaining, state.guild_to_shard, fn gid, acc ->
          Map.delete(acc, gid)
        end)

      new_state = %{
        state
        | guild_to_shard: new_g2s,
          pending_counts: Map.put(state.pending_counts, shard_id, 0)
      }

      {:noreply, mark_shard_ready(shard_id, new_state)}
    end
  end

  def handle_info(_msg, state), do: {:noreply, state}

  # ── Private ─────────────────────────────────────────────────────────

  defp mark_shard_ready(shard_id, state) do
    new_ready = MapSet.put(state.ready_shards, shard_id)

    # Cancel timeout timer if present
    case Map.get(state.shard_timers, shard_id) do
      nil -> :ok
      ref -> Process.cancel_timer(ref)
    end

    new_timers = Map.delete(state.shard_timers, shard_id)

    # Compute duration for this shard
    shard_start = Map.get(state.shard_start_times, shard_id, state.start_time)
    shard_duration = System.monotonic_time(:millisecond) - shard_start

    # Count guilds that were loaded for this shard
    original_count = Map.get(state.pending_counts, shard_id, 0)

    # Dispatch SHARD_READY event
    dispatch_shard_ready(shard_id, original_count, shard_duration)

    Logger.info(
      "[ReadyTracker] Shard #{shard_id} ready (#{original_count} guild(s) in #{shard_duration}ms)"
    )

    state = %{state | ready_shards: new_ready, shard_timers: new_timers}

    # Check if all shards are ready
    state = maybe_refresh_expected(state)

    if state.expected_shards && MapSet.size(new_ready) >= state.expected_shards do
      mark_globally_ready(state)
    else
      state
    end
  end

  defp mark_globally_ready(state) do
    :persistent_term.put(:eda_globally_ready, true)

    total_duration = System.monotonic_time(:millisecond) - state.start_time

    total_guilds =
      state.pending_counts
      |> Map.values()
      |> Enum.sum()

    # Reply to all waiters
    for from <- state.waiters do
      GenServer.reply(from, :ok)
    end

    # Dispatch ALL_SHARDS_READY event
    dispatch_all_shards_ready(
      MapSet.size(state.ready_shards),
      total_guilds,
      total_duration
    )

    Logger.info(
      "[ReadyTracker] All #{MapSet.size(state.ready_shards)} shard(s) ready " <>
        "(#{total_guilds} guild(s) in #{total_duration}ms)"
    )

    %{state | globally_ready: true, waiters: []}
  end

  defp maybe_restore_ready(state) do
    state = maybe_refresh_expected(state)

    if state.expected_shards && MapSet.size(state.ready_shards) >= state.expected_shards do
      :persistent_term.put(:eda_globally_ready, true)
      for from <- state.waiters, do: GenServer.reply(from, :ok)
      Logger.info("[ReadyTracker] All shards ready again after resuming")
      %{state | globally_ready: true, waiters: []}
    else
      state
    end
  end

  defp maybe_refresh_expected(%{expected_shards: nil} = state) do
    expected =
      try do
        :persistent_term.get(:eda_total_shards)
      rescue
        ArgumentError -> nil
      end

    %{state | expected_shards: expected}
  end

  defp maybe_refresh_expected(state), do: state

  defp dispatch_shard_ready(shard_id, guild_count, duration_ms) do
    data = %{
      "shard_id" => shard_id,
      "guild_count" => guild_count,
      "duration_ms" => duration_ms
    }

    EDA.Gateway.Events.dispatch("SHARD_READY", data)
  end

  defp dispatch_all_shards_ready(shard_count, guild_count, duration_ms) do
    data = %{
      "shard_count" => shard_count,
      "guild_count" => guild_count,
      "duration_ms" => duration_ms
    }

    EDA.Gateway.Events.dispatch("ALL_SHARDS_READY", data)
  end
end
