defmodule EDA.Collector do
  @moduledoc """
  Event collector for awaiting Discord gateway events.

  Provides Discord.js-style `await` patterns for blocking on specific events
  with filters and timeouts. Useful for interactive flows (confirmations,
  paginated menus, quizzes, etc.).

  ## Examples

      # Await a single message from a specific user in a channel
      case EDA.Collector.await(:MESSAGE_CREATE, fn msg ->
        msg.channel_id == channel_id and msg.author["id"] == user_id
      end, timeout: 30_000) do
        {:ok, message} -> handle_response(message)
        {:error, :timeout} -> send_timeout_message(channel_id)
      end

      # Await up to 5 reactions on a message
      {:ok, reactions} = EDA.Collector.await(:MESSAGE_REACTION_ADD, fn r ->
        r.message_id == msg_id
      end, max: 5, timeout: 60_000)

  Events are fed into collectors via `notify/2`, called automatically by
  `EDA.Gateway.Events` on every dispatched event.
  """

  use GenServer

  @default_timeout 30_000

  defmodule Entry do
    @moduledoc false
    defstruct [:event_types, :filter, :caller, :max, :timeout_ref, collected: []]
  end

  # ── Public API ──────────────────────────────────────────────────────

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @doc """
  Awaits one or more gateway events matching the given filter.

  `event_types` can be a single atom or a list of atoms (e.g., `:MESSAGE_CREATE`
  or `[:MESSAGE_CREATE, :MESSAGE_UPDATE]`).

  ## Options

    * `:timeout` — max wait time in milliseconds (default: `30_000`)
    * `:max` — number of events to collect before returning (default: `1`)

  ## Returns

    * `{:ok, event}` when `max` is 1
    * `{:ok, [events]}` when `max` > 1
    * `{:error, :timeout}` if timeout expires before enough events are collected
  """
  @spec await(atom() | [atom()], (term() -> boolean()), keyword()) ::
          {:ok, term()} | {:ok, [term()]} | {:error, :timeout}
  def await(event_types, filter, opts \\ []) do
    event_types = List.wrap(event_types)
    max = Keyword.get(opts, :max, 1)
    timeout = Keyword.get(opts, :timeout, @default_timeout)

    # Add buffer so GenServer.call doesn't timeout before our internal timer
    call_timeout = timeout + 5_000

    try do
      GenServer.call(__MODULE__, {:create, event_types, filter, max, timeout}, call_timeout)
    catch
      :exit, {:timeout, _} -> {:error, :timeout}
    end
  end

  @doc """
  Notifies the collector of a new event. Called by `EDA.Gateway.Events`.

  This is a non-blocking cast. If the Collector GenServer is not running,
  the notification is silently ignored.
  """
  @spec notify(atom(), term()) :: :ok
  def notify(event_type, event_struct) do
    GenServer.cast(__MODULE__, {:event, event_type, event_struct})
  catch
    :exit, _ -> :ok
  end

  # ── GenServer Callbacks ─────────────────────────────────────────────

  @impl true
  def init(_) do
    {:ok, %{collectors: %{}}}
  end

  @impl true
  def handle_call({:create, event_types, filter, max, timeout}, from, state) do
    ref = make_ref()
    timeout_ref = Process.send_after(self(), {:collector_timeout, ref}, timeout)

    entry = %Entry{
      event_types: event_types,
      filter: filter,
      caller: from,
      max: max,
      timeout_ref: timeout_ref
    }

    {:noreply, put_in(state, [:collectors, ref], entry)}
  end

  @impl true
  def handle_cast({:event, event_type, event_struct}, state) do
    {replied, collectors} =
      Enum.reduce(state.collectors, {[], state.collectors}, fn {ref, entry}, {replied, acc} ->
        maybe_collect(ref, entry, event_type, event_struct, replied, acc)
      end)

    collectors = Map.drop(collectors, replied)
    {:noreply, %{state | collectors: collectors}}
  end

  @impl true
  def handle_info({:collector_timeout, ref}, state) do
    case Map.pop(state.collectors, ref) do
      {nil, _} ->
        {:noreply, state}

      {entry, collectors} ->
        GenServer.reply(entry.caller, {:error, :timeout})
        {:noreply, %{state | collectors: collectors}}
    end
  end

  # ── Private ─────────────────────────────────────────────────────────

  defp maybe_collect(ref, entry, event_type, event_struct, replied, acc) do
    if event_type in entry.event_types and safe_filter(entry.filter, event_struct) do
      collected = [event_struct | entry.collected]
      try_complete(ref, %{entry | collected: collected}, replied, acc)
    else
      {replied, acc}
    end
  end

  defp try_complete(ref, entry, replied, acc) do
    if length(entry.collected) >= entry.max do
      Process.cancel_timer(entry.timeout_ref)
      result = format_result(entry.collected, entry.max)
      GenServer.reply(entry.caller, {:ok, result})
      {[ref | replied], acc}
    else
      {replied, Map.put(acc, ref, entry)}
    end
  end

  defp safe_filter(filter, event_struct) do
    filter.(event_struct)
  rescue
    _ -> false
  end

  defp format_result(collected, 1), do: hd(collected)
  defp format_result(collected, _), do: Enum.reverse(collected)
end
