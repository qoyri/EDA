defmodule EDA.Gateway.Connection do
  @moduledoc """
  WebSocket connection to Discord Gateway.

  Each instance represents a single shard, registered via
  `EDA.Gateway.Registry` for pid-accurate routing.

  Handles:
  - WebSocket connection lifecycle
  - Heartbeat management
  - Event reception and dispatch
  - Resume/reconnect logic
  """

  use WebSockex

  require Logger

  alias EDA.Gateway.{CloseCode, Compression, Encoding, Events, Heartbeat, ShardManager}

  defstruct [
    :token,
    :session_id,
    :resume_gateway_url,
    :heartbeat_interval,
    :heartbeat_ref,
    :seq,
    :heartbeat_ack,
    :shard,
    :compression,
    :decompressor,
    :encoding,
    :heartbeat_send_time,
    :heartbeat_latency,
    :connected_at,
    :hello_timer
  ]

  @type t :: %__MODULE__{
          token: String.t(),
          session_id: String.t() | nil,
          resume_gateway_url: String.t() | nil,
          heartbeat_interval: integer() | nil,
          heartbeat_ref: reference() | nil,
          seq: integer() | nil,
          heartbeat_ack: boolean(),
          shard: {integer(), integer()},
          compression: module(),
          decompressor: EDA.Gateway.Zlib.t() | EDA.Gateway.Zstd.t() | nil,
          encoding: module() | nil,
          heartbeat_send_time: integer() | nil,
          heartbeat_latency: integer() | nil,
          connected_at: integer() | nil,
          hello_timer: reference() | nil
        }

  # Client API

  @doc """
  Starts the Gateway connection for a shard.

  ## Options

  - `:token` — bot token (required)
  - `:shard` — `{shard_id, total_shards}` tuple (required)
  - `:gateway_url` — WebSocket URL from `/gateway/bot` (required)
  - `:compression` — decompressor module matching the URL's `compress` parameter (defaults to
    `EDA.Gateway.Compression.module/0`)
  """
  def start_link(opts) do
    token = Keyword.fetch!(opts, :token)
    shard = Keyword.fetch!(opts, :shard)
    gateway_url = Keyword.fetch!(opts, :gateway_url)
    {shard_id, _total} = shard

    state = %__MODULE__{
      token: token,
      seq: nil,
      heartbeat_ack: true,
      shard: shard,
      compression: Keyword.get_lazy(opts, :compression, &Compression.module/0),
      decompressor: nil,
      encoding: Encoding.module()
    }

    WebSockex.start_link(gateway_url, __MODULE__, state, name: via(shard_id))
  end

  @doc """
  Sends a message to a channel. Convenience function.
  """
  def send_message(channel_id, content) do
    EDA.API.Message.create(channel_id, content)
  end

  @doc """
  Sends OP 4 (Voice State Update) to join/leave a voice channel.

  Routes to the correct shard based on guild_id.
  Set `channel_id` to `nil` to leave the voice channel.
  """
  def update_voice_state(guild_id, channel_id, opts) do
    shard_id = ShardManager.shard_for_guild(guild_id)
    WebSockex.cast(via(shard_id), {:update_voice_state, guild_id, channel_id, opts})
  end

  @doc """
  Sends OP 31 (Request Soundboard Sounds) for the given guilds.

  Guilds are grouped by the shard that owns them, one request per shard. Each guild is
  answered by a `SOUNDBOARD_SOUNDS` dispatch.
  """
  @spec request_soundboard_sounds([String.t() | integer()]) :: :ok
  def request_soundboard_sounds(guild_ids) when is_list(guild_ids) do
    guild_ids
    |> Enum.map(&to_string/1)
    |> Enum.uniq()
    |> Enum.group_by(&ShardManager.shard_for_guild/1)
    |> Enum.each(fn {shard_id, ids} ->
      WebSockex.cast(via(shard_id), {:request_soundboard_sounds, ids})
    end)
  end

  @doc """
  Sends OP 43 (Request Channel Info) for a guild, on the shard that owns it. Answered by a
  `CHANNEL_INFO` dispatch.
  """
  @spec request_channel_info(String.t(), [String.t()]) :: :ok
  def request_channel_info(guild_id, fields) do
    shard_id = ShardManager.shard_for_guild(guild_id)
    WebSockex.cast(via(shard_id), {:request_channel_info, guild_id, fields})
  end

  defp via(shard_id), do: {:via, Registry, {EDA.Gateway.Registry, shard_id}}

  # WebSockex Callbacks

  @impl true
  def handle_connect(_conn, state) do
    Logger.info("#{shard_label(state)} Connected to Discord Gateway")

    # Init the decompressor on first connect (a zlib context must be created in the WebSockex
    # process), reset it on subsequent reconnects.
    decompressor =
      case state.decompressor do
        nil ->
          {:ok, d} = state.compression.init()
          d

        existing ->
          state.compression.reset(existing)
      end

    hello_timer = Process.send_after(self(), :hello_timeout, 20_000)

    {:ok,
     %{
       state
       | decompressor: decompressor,
         connected_at: System.monotonic_time(:millisecond),
         hello_timer: hello_timer
     }}
  end

  @doc """
  Returns the heartbeat latency in milliseconds for a shard, or `nil` if unknown.
  """
  @spec heartbeat_latency(non_neg_integer()) :: non_neg_integer() | nil
  def heartbeat_latency(shard_id) do
    case Registry.lookup(EDA.Gateway.Registry, shard_id) do
      [{pid, _}] ->
        ref = make_ref()

        Logger.debug(
          "heartbeat_latency: found pid #{inspect(pid)} for shard #{shard_id}, casting get_latency"
        )

        WebSockex.cast(pid, {:get_latency, self(), ref})

        receive do
          {:heartbeat_latency, ^ref, latency} ->
            Logger.debug("heartbeat_latency: got response #{inspect(latency)}")
            latency
        after
          1_000 ->
            Logger.warning(
              "heartbeat_latency: timeout waiting for response from shard #{shard_id}"
            )

            nil
        end

      [] ->
        Logger.warning("heartbeat_latency: no process found in Registry for shard #{shard_id}")
        nil
    end
  end

  @doc """
  Returns connection metadata for a shard: latency, uptime, heartbeat interval.
  """
  @spec connection_info(non_neg_integer()) :: map() | nil
  def connection_info(shard_id) do
    case Registry.lookup(EDA.Gateway.Registry, shard_id) do
      [{pid, _}] ->
        ref = make_ref()
        WebSockex.cast(pid, {:get_info, self(), ref})

        receive do
          {:connection_info, ^ref, info} -> info
        after
          1_000 -> nil
        end

      [] ->
        nil
    end
  end

  @impl true
  # Remote close with explicit code
  def handle_disconnect(%{reason: {:remote, code, msg}}, state) do
    Logger.warning(
      "#{shard_label(state)} Disconnected: #{CloseCode.reason(code)} (#{code}) — #{msg}"
    )

    Heartbeat.cancel(state.heartbeat_ref)
    dispatch_gateway_close(state, code, CloseCode.action(code))
    handle_close_action(CloseCode.action(code), state)
  end

  # Remote normal close (code 1000 implicit)
  def handle_disconnect(%{reason: {:remote, :normal}}, state) do
    Logger.info("#{shard_label(state)} Disconnected normally")
    Heartbeat.cancel(state.heartbeat_ref)
    dispatch_gateway_close(state, 1000, :resume)
    handle_close_action(:resume, state)
  end

  # Remote abrupt close (no close frame)
  def handle_disconnect(%{reason: {:remote, :closed}}, state) do
    Logger.warning("#{shard_label(state)} Connection closed abruptly (no close frame)")
    Heartbeat.cancel(state.heartbeat_ref)
    dispatch_gateway_close(state, nil, :reconnect)
    handle_close_action(:reconnect, state)
  end

  # Local close (we initiated it, e.g. zombie detection)
  def handle_disconnect(%{reason: {:local, code, _msg}}, state) do
    Logger.info("#{shard_label(state)} Local close: #{CloseCode.reason(code)}")
    Heartbeat.cancel(state.heartbeat_ref)
    dispatch_gateway_close(state, code, CloseCode.action(code))
    handle_close_action(CloseCode.action(code), state)
  end

  def handle_disconnect(%{reason: {:local, :normal}}, state) do
    Logger.info("#{shard_label(state)} Local normal close")
    Heartbeat.cancel(state.heartbeat_ref)
    dispatch_gateway_close(state, nil, :resume)
    handle_close_action(:resume, state)
  end

  # Error (network failure, SSL error, etc.)
  def handle_disconnect(%{reason: {:error, reason}}, state) do
    Logger.warning("#{shard_label(state)} Connection error: #{inspect(reason)}")
    Heartbeat.cancel(state.heartbeat_ref)
    dispatch_gateway_close(state, nil, :reconnect)
    handle_close_action(:reconnect, state)
  end

  # Fallback
  def handle_disconnect(%{reason: reason}, state) do
    Logger.warning("#{shard_label(state)} Disconnected: #{inspect(reason)}")
    Heartbeat.cancel(state.heartbeat_ref)
    dispatch_gateway_close(state, nil, :reconnect)
    handle_close_action(:reconnect, state)
  end

  @impl true
  def terminate(reason, state) do
    if state.decompressor, do: state.compression.close(state.decompressor)
    Logger.debug("#{shard_label(state)} Terminated: #{inspect(reason)}")
    :ok
  end

  @impl true
  def handle_frame({:binary, compressed}, state) do
    case state.compression.push(state.decompressor, compressed) do
      {:ok, decompressed, decompressor} ->
        case safe_decode(state.encoding, decompressed) do
          {:ok, payload} ->
            handle_payload(payload, %{state | decompressor: decompressor})

          {:error, reason} ->
            Logger.error("#{shard_label(state)} Decode error: #{inspect(reason)}")
            {:ok, %{state | decompressor: decompressor}}
        end

      {:incomplete, decompressor} ->
        {:ok, %{state | decompressor: decompressor}}

      {:error, reason, decompressor} ->
        Logger.error("#{shard_label(state)} Decompression failed: #{inspect(reason)}")
        {:close, %{state | decompressor: decompressor}}
    end
  end

  def handle_frame({:text, payload}, state) do
    case safe_decode(state.encoding, payload) do
      {:ok, decoded} ->
        handle_payload(decoded, state)

      {:error, reason} ->
        Logger.error("#{shard_label(state)} Decode error: #{inspect(reason)}")
        {:ok, state}
    end
  end

  def handle_frame(_frame, state), do: {:ok, state}

  @impl true
  def handle_cast({:heartbeat}, state) do
    send_heartbeat(state)
  end

  def handle_cast({:get_latency, caller, ref}, state) do
    send(caller, {:heartbeat_latency, ref, state.heartbeat_latency})
    {:ok, state}
  end

  def handle_cast({:get_info, caller, ref}, state) do
    now = System.monotonic_time(:millisecond)

    uptime_ms =
      if state.connected_at, do: now - state.connected_at, else: nil

    info = %{
      latency: state.heartbeat_latency,
      heartbeat_interval: state.heartbeat_interval,
      uptime_ms: uptime_ms,
      seq: state.seq,
      session_id: state.session_id,
      shard: state.shard
    }

    send(caller, {:connection_info, ref, info})
    {:ok, state}
  end

  def handle_cast({:update_presence, presence}, state) do
    payload = %{
      op: 3,
      d: EDA.Presence.to_map(presence)
    }

    {:reply, state.encoding.encode(payload), state}
  end

  def handle_cast({:request_guild_members, payload}, state) do
    frame = %{op: 8, d: payload}
    {:reply, state.encoding.encode(frame), state}
  end

  def handle_cast({:request_channel_info, guild_id, fields}, state) do
    frame = %{op: 43, d: %{guild_id: guild_id, fields: fields}}
    {:reply, state.encoding.encode(frame), state}
  end

  def handle_cast({:request_soundboard_sounds, guild_ids}, state) do
    frame = %{op: 31, d: %{guild_ids: guild_ids}}
    {:reply, state.encoding.encode(frame), state}
  end

  def handle_cast({:update_voice_state, guild_id, channel_id, opts}, state) do
    Logger.debug(
      "#{shard_label(state)} Sending OP 4 Voice State Update: guild=#{guild_id} channel=#{channel_id}"
    )

    payload = %{
      op: 4,
      d: %{
        guild_id: guild_id,
        channel_id: channel_id,
        self_mute: Keyword.get(opts, :mute, false),
        self_deaf: Keyword.get(opts, :deaf, false)
      }
    }

    {:reply, state.encoding.encode(payload), state}
  end

  @impl true
  def handle_info({:heartbeat}, state) do
    if state.heartbeat_ack do
      send_heartbeat(%{state | heartbeat_ack: false})
    else
      Logger.warning("#{shard_label(state)} Heartbeat ACK not received, reconnecting...")
      {:close, {4900, "Zombie connection"}, state}
    end
  end

  def handle_info(:hello_timeout, state) do
    Logger.error("#{shard_label(state)} HELLO not received within 20s, closing")
    {:close, {4900, "HELLO timeout"}, state}
  end

  def handle_info(_msg, state), do: {:ok, state}

  # Payload Handling

  defp handle_payload(%{"op" => 10, "d" => %{"heartbeat_interval" => interval}}, state) do
    Logger.debug("#{shard_label(state)} Received HELLO, heartbeat interval: #{interval}ms")

    # Cancel HELLO timeout
    if state.hello_timer, do: Process.cancel_timer(state.hello_timer)
    state = %{state | hello_timer: nil}

    # Cancel any stale heartbeat timer from a previous session
    Heartbeat.cancel(state.heartbeat_ref)

    # First heartbeat uses jitter per Discord docs: interval * random(0, 1)
    ref = Heartbeat.start_first(interval)

    new_state = %{state | heartbeat_interval: interval, heartbeat_ref: ref, heartbeat_ack: true}

    # Send IDENTIFY or RESUME
    if state.session_id do
      send_resume(new_state)
    else
      send_identify(new_state)
    end
  end

  # Heartbeat ACK
  defp handle_payload(%{"op" => 11}, state) do
    latency =
      if state.heartbeat_send_time do
        System.monotonic_time(:millisecond) - state.heartbeat_send_time
      end

    Logger.debug("#{shard_label(state)} Received Heartbeat ACK (#{latency}ms)")
    {:ok, %{state | heartbeat_ack: true, heartbeat_latency: latency}}
  end

  # Dispatch event
  defp handle_payload(%{"op" => 0, "t" => event_type, "s" => seq, "d" => data}, state) do
    new_state = %{state | seq: seq}

    case event_type do
      "READY" ->
        handle_ready(data, new_state)

      "RESUMED" ->
        {shard_id, _} = state.shard
        Logger.info("#{shard_label(state)} Successfully resumed session")
        EDA.Gateway.ReadyTracker.shard_resumed(shard_id)
        Events.dispatch("SESSION_RESUMED", %{"shard_id" => shard_id})
        {:ok, new_state}

      _ ->
        # Dispatch to consumer
        Events.dispatch(event_type, data)
        {:ok, new_state}
    end
  end

  # Server-requested heartbeat — must respond immediately
  defp handle_payload(%{"op" => 1}, state) do
    Logger.debug("#{shard_label(state)} Server requested immediate heartbeat")
    payload = %{op: 1, d: state.seq}
    now = System.monotonic_time(:millisecond)
    {:reply, state.encoding.encode(payload), %{state | heartbeat_send_time: now}}
  end

  # Reconnect request
  defp handle_payload(%{"op" => 7}, state) do
    Logger.info("#{shard_label(state)} Gateway requested reconnect")
    {:close, state}
  end

  # Invalid session
  defp handle_payload(%{"op" => 9, "d" => resumable}, state) do
    Logger.warning("#{shard_label(state)} Invalid session, resumable: #{resumable}")

    if resumable do
      Process.sleep(1000 + :rand.uniform(5000))
      {:close, state}
    else
      {:close, %{state | session_id: nil, seq: nil}}
    end
  end

  defp handle_payload(payload, state) do
    Logger.debug("#{shard_label(state)} Unhandled payload: #{inspect(payload)}")
    {:ok, state}
  end

  @doc false
  # The session id of a shard's gateway connection, as Discord puts it in the bot's voice states;
  # `nil` before its first READY.
  @spec session_id(non_neg_integer()) :: String.t() | nil
  def session_id(shard_id), do: :persistent_term.get({__MODULE__, :session_id, shard_id}, nil)

  # Event Handlers

  defp handle_ready(data, state) do
    session_id = data["session_id"]
    resume_url = data["resume_gateway_url"]
    user = data["user"]
    {shard_id, _} = state.shard

    Logger.info("#{shard_label(state)} Bot ready as #{user["username"]}##{user["discriminator"]}")

    # Extract guild IDs from READY payload
    guild_ids = Enum.map(data["guilds"] || [], & &1["id"])

    # Notify ShardManager
    ShardManager.shard_connected(shard_id)

    # Register pending guilds with ReadyTracker
    EDA.Gateway.ReadyTracker.shard_ready(shard_id, guild_ids)

    # Store current user in cache
    EDA.Cache.put_me(user)

    # EDA.Voice tells its own voice states from another process's on the same token by this id.
    :persistent_term.put({__MODULE__, :session_id, shard_id}, session_id)

    # Dispatch READY event
    Events.dispatch("READY", data)

    {:ok, %{state | session_id: session_id, resume_gateway_url: resume_url}}
  end

  # Sending Payloads

  defp send_identify(state) do
    {os, _} = :os.type()
    platform = Application.get_env(:eda, :platform, :desktop)

    d = %{
      token: state.token,
      intents: EDA.intents(),
      properties: %{
        os: to_string(os),
        browser: browser_string(platform),
        device: "EDA"
      },
      shard: Tuple.to_list(state.shard)
    }

    d = d |> maybe_add_presence() |> maybe_add_capabilities()
    payload = %{op: 2, d: d}

    Logger.debug(
      "#{shard_label(state)} Sending IDENTIFY (platform=#{platform}, presence=#{Map.has_key?(d, :presence)})"
    )

    if Map.has_key?(d, :presence) do
      Logger.info(
        "#{shard_label(state)} Presence: status=#{d.presence.status}, activities=#{length(d.presence.activities)}"
      )
    end

    {:reply, state.encoding.encode(payload), state}
  end

  defp send_resume(state) do
    payload = %{
      op: 6,
      d: %{
        token: state.token,
        session_id: state.session_id,
        seq: state.seq
      }
    }

    Logger.debug("#{shard_label(state)} Sending RESUME")
    {:reply, state.encoding.encode(payload), state}
  end

  defp send_heartbeat(state) do
    payload = %{op: 1, d: state.seq}
    Logger.debug("#{shard_label(state)} Sending heartbeat (seq: #{state.seq})")

    # Cancel previous timer to prevent leaks
    Heartbeat.cancel(state.heartbeat_ref)

    ref = Heartbeat.start(state.heartbeat_interval)
    now = System.monotonic_time(:millisecond)

    {:reply, state.encoding.encode(payload),
     %{state | heartbeat_ref: ref, heartbeat_send_time: now}}
  end

  defp browser_string(:desktop), do: "EDA"
  defp browser_string(:mobile), do: "Discord iOS"
  defp browser_string(:mobile_ios), do: "Discord iOS"
  defp browser_string(:mobile_android), do: "Discord Android"
  defp browser_string(:web), do: "EDA Web"
  defp browser_string(custom) when is_binary(custom), do: custom

  # Omitted entirely when nothing is configured, so the default IDENTIFY is byte
  # identical to before. See EDA.Gateway.Capabilities.
  # Public (but undocumented) so the test suite can exercise the real function
  # rather than a copy of it.
  @doc false
  def maybe_add_capabilities(d) do
    case EDA.capabilities() do
      0 -> d
      bitfield -> Map.put(d, :capabilities, bitfield)
    end
  end

  defp maybe_add_presence(d) do
    case Application.get_env(:eda, :presence) do
      %EDA.Presence{} = presence ->
        Map.put(d, :presence, EDA.Presence.to_map(presence))

      opts when is_list(opts) ->
        Map.put(d, :presence, EDA.Presence.to_map(EDA.Presence.new(opts)))

      _ ->
        d
    end
  end

  defp safe_decode(encoding, data) do
    {:ok, encoding.decode(data)}
  rescue
    e -> {:error, Exception.message(e)}
  end

  defp shard_label(state) do
    {id, total} = state.shard
    "[Shard #{id}/#{total}]"
  end

  # Close action handlers

  defp handle_close_action(:fatal, state) do
    Logger.error(
      "#{shard_label(state)} Fatal close code — will NOT reconnect. Check token/intents/shard config."
    )

    {:ok, %{state | heartbeat_ref: nil}}
  end

  defp handle_close_action(:session_reset, state) do
    Logger.info("#{shard_label(state)} Session invalidated, will reconnect with fresh IDENTIFY")
    {:reconnect, %{state | session_id: nil, seq: nil, heartbeat_ref: nil}}
  end

  defp handle_close_action(:resume, state) do
    if state.session_id && state.resume_gateway_url do
      Logger.info("#{shard_label(state)} Will attempt to resume session")
      {:reconnect, %{state | heartbeat_ref: nil}}
    else
      {:reconnect, %{state | session_id: nil, seq: nil, heartbeat_ref: nil}}
    end
  end

  defp handle_close_action(:reconnect, state) do
    {:reconnect, %{state | session_id: nil, seq: nil, heartbeat_ref: nil}}
  end

  defp dispatch_gateway_close(state, code, action) do
    {shard_id, _} = state.shard
    will_reconnect = action != :fatal

    # Every disconnect path comes through here, so this is where the shard stops counting
    # as ready. It counts again on RESUMED, or on a fresh READY.
    EDA.Gateway.ReadyTracker.shard_disconnected(shard_id)

    Events.dispatch("GATEWAY_CLOSE", %{
      "shard_id" => shard_id,
      "code" => code,
      "reason" => if(code, do: CloseCode.reason(code), else: nil),
      "action" => to_string(action),
      "will_reconnect" => will_reconnect
    })
  end
end
