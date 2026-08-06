defmodule EDA.Gateway.MemberChunker do
  @moduledoc """
  Orchestrates OP 8 (Request Guild Members) requests with nonce-based tracking.

  Supports fire-and-forget caching, synchronous awaiting, prefix search, and
  fetching by user IDs. Chunks are tracked by nonce and requests are cleaned up
  on timeout.

  Discord rate limits requests for *all* members of a guild (`query: ""` and
  `limit: 0`) to one per guild every 30 seconds. Those requests are throttled
  here: a request made during the cooldown is queued and sent when the window
  opens, so callers never silently lose a request. Prefix searches and
  `user_ids` lookups are exempt and always go out immediately.

  The cooldown can be tuned with `config :eda, member_chunk_cooldown_ms: 30_000`.
  """

  use GenServer

  require Logger

  @timeout_ms 15_000
  @cleanup_interval 5_000
  @cooldown_ms 30_000

  defmodule ChunkRequest do
    @moduledoc false
    defstruct [
      :nonce,
      :guild_id,
      :caller,
      :chunk_count,
      :started_at,
      :opts,
      chunks_received: 0,
      members: []
    ]
  end

  defmodule Pending do
    @moduledoc false
    defstruct [:guild_id, :opts, :caller]
  end

  # ── Public API ──────────────────────────────────────────────────────

  @doc "Fire-and-forget: requests all members for a guild, caches automatically."
  @spec request(String.t() | integer(), keyword()) :: :ok
  def request(guild_id, opts \\ []) do
    GenServer.cast(__MODULE__, {:request, to_string(guild_id), nil, opts})
  end

  @doc "Requests all members and blocks until all chunks arrive."
  @spec await(String.t() | integer(), keyword()) :: {:ok, [map()]} | {:error, :timeout}
  def await(guild_id, opts \\ []) do
    GenServer.call(__MODULE__, {:request, to_string(guild_id), opts}, call_timeout())
  end

  @doc "Searches members by username prefix (max 100 results)."
  @spec search(String.t() | integer(), String.t(), keyword()) ::
          {:ok, [map()]} | {:error, :timeout}
  def search(guild_id, query, opts \\ []) do
    opts = Keyword.merge([query: query, limit: min(Keyword.get(opts, :limit, 100), 100)], opts)
    GenServer.call(__MODULE__, {:request, to_string(guild_id), opts}, call_timeout())
  end

  @doc "Fetches specific members by user IDs (max 100)."
  @spec fetch(String.t() | integer(), [String.t() | integer()], keyword()) ::
          {:ok, [map()]} | {:error, :timeout}
  def fetch(guild_id, user_ids, opts \\ []) do
    ids = user_ids |> Enum.take(100) |> Enum.map(&to_string/1)
    opts = Keyword.put(opts, :user_ids, ids)
    GenServer.call(__MODULE__, {:request, to_string(guild_id), opts}, call_timeout())
  end

  @doc "Called by Events when a GUILD_MEMBERS_CHUNK arrives."
  @spec handle_chunk(map()) :: :ok
  def handle_chunk(data) do
    GenServer.cast(__MODULE__, {:chunk, data})
  end

  @doc "Called by Events when Discord answers an OP 8 with a RATE_LIMITED dispatch."
  @spec handle_rate_limited(map()) :: :ok
  def handle_rate_limited(data) do
    GenServer.cast(__MODULE__, {:rate_limited, data})
  end

  # ── GenServer ───────────────────────────────────────────────────────

  def start_link(_opts \\ []) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @impl true
  def init(_) do
    schedule_cleanup()
    {:ok, %{requests: %{}, cooldowns: %{}, pending: %{}}}
  end

  @impl true
  def handle_call({:request, guild_id, opts}, from, state) do
    {:noreply, dispatch_or_queue(state, guild_id, opts, from)}
  end

  @impl true
  def handle_cast({:request, guild_id, nil, opts}, state) do
    {:noreply, dispatch_or_queue(state, guild_id, opts, nil)}
  end

  def handle_cast({:rate_limited, data}, state) do
    meta = data["meta"] || %{}
    guild_id = meta["guild_id"]

    if is_nil(guild_id) do
      {:noreply, state}
    else
      # Discord is the authority: its retry_after wins over the local counter,
      # which can drift across restarts or shards.
      delay = round((data["retry_after"] || 0) * 1000)
      now = System.monotonic_time(:millisecond)
      state = put_in(state, [:cooldowns, guild_id], now + delay)

      Logger.debug(
        "MemberChunker: OP 8 rate limited for guild #{guild_id}, retrying in #{delay}ms"
      )

      {:noreply, requeue_rejected(state, guild_id, meta["nonce"], delay)}
    end
  end

  def handle_cast({:chunk, data}, state) do
    nonce = data["nonce"]

    case Map.fetch(state.requests, nonce) do
      {:ok, request} ->
        {:noreply, process_chunk(state, nonce, request, data)}

      :error ->
        {:noreply, state}
    end
  end

  @impl true
  def handle_info(:cleanup, state) do
    now = System.monotonic_time(:millisecond)

    {expired, remaining} =
      Map.split_with(state.requests, fn {_nonce, req} ->
        now - req.started_at > @timeout_ms
      end)

    for {_nonce, req} <- expired do
      if req.caller do
        GenServer.reply(req.caller, {:error, :timeout})
      end

      Logger.debug("MemberChunker: timed out request for guild #{req.guild_id}")
    end

    schedule_cleanup()
    {:noreply, %{state | requests: remaining}}
  end

  def handle_info({:drain, guild_id}, state) do
    now = System.monotonic_time(:millisecond)
    ready_at = Map.get(state.cooldowns, guild_id, now)

    case Map.get(state.pending, guild_id, []) do
      [] ->
        {:noreply, state}

      [next | rest] when now >= ready_at ->
        state =
          state
          |> send_now(guild_id, next.opts, next.caller, now)
          |> put_pending(guild_id, rest)

        if rest != [], do: Process.send_after(self(), {:drain, guild_id}, cooldown_ms())
        {:noreply, state}

      _still_cooling ->
        Process.send_after(self(), {:drain, guild_id}, ready_at - now)
        {:noreply, state}
    end
  end

  def handle_info(_msg, state), do: {:noreply, state}

  # ── OP 8 throttle ────────────────────────────────────────────────────
  #
  # Discord rate limits "all members" requests (query="" and limit=0) to one
  # per guild per 30 seconds. Prefix searches and user_ids lookups are exempt.

  defp all_members?(opts) do
    opts = opts || []

    is_nil(Keyword.get(opts, :user_ids)) and
      Keyword.get(opts, :query, "") == "" and
      Keyword.get(opts, :limit, 0) == 0
  end

  defp dispatch_or_queue(state, guild_id, opts, caller) do
    # Monotonic time can be negative, so an absent cooldown defaults to `now`
    # (ready) rather than to zero.
    now = System.monotonic_time(:millisecond)
    ready_at = Map.get(state.cooldowns, guild_id, now)

    cond do
      not all_members?(opts) -> send_now(state, guild_id, opts, caller, now)
      now >= ready_at -> send_now(state, guild_id, opts, caller, now)
      true -> enqueue(state, guild_id, opts, caller, ready_at - now)
    end
  end

  defp send_now(state, guild_id, opts, caller, now) do
    nonce = generate_nonce()
    send_op8(guild_id, nonce, opts)

    request = %ChunkRequest{
      nonce: nonce,
      guild_id: guild_id,
      caller: caller,
      started_at: now,
      opts: opts
    }

    state = put_in(state, [:requests, nonce], request)

    if all_members?(opts) do
      put_in(state, [:cooldowns, guild_id], now + cooldown_ms())
    else
      state
    end
  end

  defp enqueue(state, guild_id, opts, caller, delay) do
    queue = Map.get(state.pending, guild_id, [])

    # A duplicate fire-and-forget is the same request: drop it rather than
    # let a GUILD_CREATE burst pile up. Callers awaiting a reply are kept.
    if is_nil(caller) and Enum.any?(queue, &is_nil(&1.caller)) do
      state
    else
      Process.send_after(self(), {:drain, guild_id}, max(delay, 0))
      pending = %Pending{guild_id: guild_id, opts: opts, caller: caller}
      put_pending(state, guild_id, queue ++ [pending])
    end
  end

  # A rejected request goes back to the *head* of the queue: it arrived before
  # anything still waiting.
  defp requeue_rejected(state, guild_id, nonce, delay) do
    case nonce && Map.fetch(state.requests, nonce) do
      {:ok, request} ->
        state = %{state | requests: Map.delete(state.requests, nonce)}
        queue = Map.get(state.pending, guild_id, [])
        pending = %Pending{guild_id: guild_id, opts: request.opts, caller: request.caller}
        Process.send_after(self(), {:drain, guild_id}, delay)
        put_pending(state, guild_id, [pending | queue])

      _ ->
        state
    end
  end

  defp put_pending(state, guild_id, []),
    do: %{state | pending: Map.delete(state.pending, guild_id)}

  defp put_pending(state, guild_id, queue), do: put_in(state, [:pending, guild_id], queue)

  # ── Chunk processing ─────────────────────────────────────────────────

  defp process_chunk(state, nonce, request, data) do
    members = data["members"] || []
    chunk_index = data["chunk_index"] || 0
    chunk_count = data["chunk_count"] || 1

    cache_chunk(request.guild_id, members, data["presences"])

    updated = %{
      request
      | chunk_count: chunk_count,
        chunks_received: request.chunks_received + 1,
        members: request.members ++ members
    }

    complete_or_continue(state, nonce, updated, chunk_index, chunk_count)
  end

  defp cache_chunk(guild_id, members, presences) do
    for member <- members do
      if user = member["user"], do: EDA.Cache.User.create(user)
      EDA.Cache.Member.create(guild_id, member)
    end

    for presence <- presences || [] do
      EDA.Cache.Presence.upsert(guild_id, presence)
    end
  end

  defp complete_or_continue(state, nonce, request, chunk_index, chunk_count)
       when chunk_index == chunk_count - 1 do
    if request.caller, do: GenServer.reply(request.caller, {:ok, request.members})
    %{state | requests: Map.delete(state.requests, nonce)}
  end

  defp complete_or_continue(state, nonce, request, _chunk_index, _chunk_count) do
    put_in(state, [:requests, nonce], request)
  end

  # ── Internals ───────────────────────────────────────────────────────

  defp cooldown_ms, do: Application.get_env(:eda, :member_chunk_cooldown_ms, @cooldown_ms)

  defp call_timeout, do: @timeout_ms + cooldown_ms() + 5_000

  defp generate_nonce do
    :crypto.strong_rand_bytes(8) |> Base.hex_encode32(case: :lower, padding: false)
  end

  defp send_op8(guild_id, nonce, opts) do
    payload = build_op8_payload(guild_id, nonce, opts)

    try do
      shard_id = EDA.Gateway.ShardManager.shard_for_guild(guild_id)
      via = {:via, Registry, {EDA.Gateway.Registry, shard_id}}
      WebSockex.cast(via, {:request_guild_members, payload})
    rescue
      e ->
        Logger.warning(
          "MemberChunker: failed to send OP 8 for guild #{guild_id}: #{Exception.message(e)}"
        )
    end
  end

  defp build_op8_payload(guild_id, nonce, opts) do
    opts = opts || []
    user_ids = Keyword.get(opts, :user_ids)

    base = %{guild_id: guild_id, nonce: nonce}

    if user_ids do
      Map.put(base, :user_ids, user_ids)
    else
      query = Keyword.get(opts, :query, "")
      limit = Keyword.get(opts, :limit, 0)
      base |> Map.put(:query, query) |> Map.put(:limit, limit)
    end
  end

  defp schedule_cleanup do
    Process.send_after(self(), :cleanup, @cleanup_interval)
  end
end
