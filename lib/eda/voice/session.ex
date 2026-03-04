defmodule EDA.Voice.Session do
  @moduledoc """
  WebSocket connection to a Discord Voice Gateway (one per guild).

  Uses v8 of the voice gateway protocol.
  On 4006 (session invalid), triggers a full restart (leave + rejoin)
  to obtain fresh credentials.
  """

  use WebSockex

  require Logger

  alias EDA.Voice.{Crypto, Dave, Event, Payload}

  # 4006 = session no longer valid → restart with fresh credentials
  @restart_close_codes [4006]

  # 4014 = bot was disconnected from voice (kicked by admin, etc.)
  @disconnect_close_codes [4014]

  # Other fatal codes → give up, don't reconnect
  @fatal_close_codes [4004, 4009, 4011, 4016]

  defstruct [
    :guild_id,
    :channel_id,
    :session_id,
    :token,
    :endpoint,
    :ssrc,
    :secret_key,
    :encryption_mode,
    :udp_socket,
    :ip,
    :port,
    :heartbeat_interval,
    :heartbeat_ref,
    heartbeat_ack: true,
    ready: false,
    listening: false,
    seq_ack: 0,
    ssrc_map: %{},
    dave_manager: nil
  ]

  @type t :: %__MODULE__{}

  @doc false
  def child_spec(opts) do
    guild_id = Keyword.fetch!(opts, :guild_id)

    %{
      id: {__MODULE__, guild_id},
      start: {__MODULE__, :start_link, [opts]},
      restart: :temporary
    }
  end

  @doc """
  Starts a voice gateway WebSocket connection.
  """
  def start_link(opts) do
    guild_id = Keyword.fetch!(opts, :guild_id)
    channel_id = Keyword.fetch!(opts, :channel_id)
    session_id = Keyword.fetch!(opts, :session_id)
    token = Keyword.fetch!(opts, :token)
    endpoint = Keyword.fetch!(opts, :endpoint)

    url = build_url(endpoint)

    state = %__MODULE__{
      guild_id: guild_id,
      channel_id: channel_id,
      session_id: session_id,
      token: token,
      endpoint: endpoint
    }

    Logger.info("Connecting to voice gateway: #{url}")

    WebSockex.start_link(url, __MODULE__, state,
      name: via(guild_id),
      handle_initial_conn_failure: true
    )
  end

  @doc """
  Sends a payload to the voice gateway.
  """
  def send_payload(guild_id, payload) do
    WebSockex.cast(via(guild_id), {:send_payload, payload})
  rescue
    ArgumentError ->
      {:error, :not_connected}
  catch
    :exit, _ ->
      {:error, :not_connected}
  end

  @doc """
  Enables continuous audio receiving for the given guild.
  Incoming voice packets will be dispatched as `VOICE_AUDIO` events.
  """
  def start_listening(guild_id) do
    WebSockex.cast(via(guild_id), :start_listening)
  end

  @doc """
  Disables continuous audio receiving for the given guild.
  """
  def stop_listening(guild_id) do
    WebSockex.cast(via(guild_id), :stop_listening)
  end

  @doc """
  Returns the registry-based name for a voice session.
  """
  def via(guild_id) do
    {:via, Registry, {EDA.Voice.Registry, {:session, guild_id}}}
  end

  # WebSockex Callbacks

  @impl true
  def handle_connect(_conn, state) do
    Logger.info("Connected to voice gateway for guild #{state.guild_id}")
    {:ok, state}
  end

  # 4006 → session invalid, restart with fresh credentials (leave + rejoin)
  @impl true
  def handle_disconnect(%{reason: {:remote, code, msg}}, state)
      when code in @restart_close_codes do
    Logger.warning(
      "Voice session invalid (#{code}: #{msg}) for guild #{state.guild_id}, will restart"
    )

    cleanup_state(state)
    EDA.Voice.restart_session(state.guild_id)
    {:ok, %{state | ready: false, udp_socket: nil, secret_key: nil}}
  end

  # 4014 → bot was disconnected from voice. Attempt a bounded restart/rejoin
  # through EDA.Voice state management.
  def handle_disconnect(%{reason: {:remote, code, _msg}}, state)
      when code in @disconnect_close_codes do
    Logger.warning(
      "Voice session ended for guild #{state.guild_id} with 4014 (disconnected), attempting restart"
    )

    cleanup_state(state)
    EDA.Voice.restart_session(state.guild_id)
    {:ok, %{state | ready: false, udp_socket: nil, secret_key: nil}}
  end

  # Other fatal codes → give up
  def handle_disconnect(%{reason: {:remote, code, msg}}, state)
      when code in @fatal_close_codes do
    Logger.error(
      "Voice gateway fatal #{code} (#{msg}) for guild #{state.guild_id}, not reconnecting"
    )

    cleanup_state(state)
    EDA.Voice.voice_disconnected(state.guild_id)
    {:ok, %{state | ready: false, udp_socket: nil, secret_key: nil}}
  end

  # Other disconnects → give up
  def handle_disconnect(%{reason: reason}, state) do
    Logger.warning("Voice gateway disconnected for guild #{state.guild_id}: #{inspect(reason)}")
    cleanup_state(state)
    EDA.Voice.voice_disconnected(state.guild_id)
    {:ok, %{state | ready: false, udp_socket: nil, secret_key: nil}}
  end

  # Text frames
  @impl true
  def handle_frame({:text, payload}, state) do
    payload
    |> Jason.decode!()
    |> Event.handle(state)
    |> handle_event_result()
  end

  # Binary DAVE control frames (v8):
  # <<sequence::16, opcode::8, payload::binary>>
  def handle_frame({:binary, <<seq::16-big, op::8, payload::binary>>}, state)
      when op in [25, 27, 29, 30] do
    new_state = %{state | seq_ack: max(state.seq_ack, seq)}

    dave_data =
      case {op, payload} do
        {25, external_sender} ->
          %{"external_sender_bin" => external_sender}

        {27, <<operation_type::8, proposals::binary>>} ->
          %{"operation_type" => operation_type, "proposals_bin" => proposals}

        {29, <<transition_id::16-big, commit::binary>>} ->
          %{"transition_id" => transition_id, "commit_bin" => commit}

        {30, welcome_payload} ->
          transition_id =
            case welcome_payload do
              <<tid::16-big, _::binary>> -> tid
              _ -> 0
            end

          %{"transition_id" => transition_id, "welcome_bin" => welcome_payload}

        _ ->
          %{}
      end

    %{"op" => op, "d" => dave_data}
    |> Event.handle(new_state)
    |> handle_event_result()
  end

  # Binary frames with 2-byte sequence prefix (v8)
  def handle_frame({:binary, <<seq::16-big, json::binary>>}, state) do
    new_state = %{state | seq_ack: max(state.seq_ack, seq)}

    case Jason.decode(json) do
      {:ok, decoded} ->
        decoded
        |> Event.handle(new_state)
        |> handle_event_result()

      {:error, _} ->
        Logger.debug("Voice binary frame seq=#{seq} (#{byte_size(json)} bytes, not JSON)")
        {:ok, new_state}
    end
  end

  def handle_frame(_frame, state), do: {:ok, state}

  @impl true
  def handle_cast({:send_payload, {:binary, payload}}, state) when is_binary(payload) do
    {:reply, {:binary, payload}, state}
  end

  def handle_cast({:send_payload, payload}, state) do
    {:reply, {:text, Jason.encode!(payload)}, state}
  end

  def handle_cast(:start_listening, %{udp_socket: socket, ready: true} = state)
      when not is_nil(socket) do
    :inet.setopts(socket, active: true)
    Logger.info("Voice listening enabled for guild #{state.guild_id}")
    {:ok, %{state | listening: true}}
  end

  def handle_cast(:start_listening, state) do
    Logger.warning("Cannot start listening: voice not ready for guild #{state.guild_id}")
    {:ok, state}
  end

  def handle_cast(:stop_listening, %{udp_socket: socket, listening: true} = state)
      when not is_nil(socket) do
    :inet.setopts(socket, active: false)
    Logger.info("Voice listening disabled for guild #{state.guild_id}")
    {:ok, %{state | listening: false}}
  end

  def handle_cast(:stop_listening, state) do
    {:ok, %{state | listening: false}}
  end

  @impl true
  def handle_info(:voice_heartbeat, state) do
    if state.heartbeat_ack do
      nonce = System.monotonic_time(:millisecond)
      payload = Payload.heartbeat(nonce, state.seq_ack)

      ref = Process.send_after(self(), :voice_heartbeat, state.heartbeat_interval)

      {:reply, {:text, Jason.encode!(payload)},
       %{state | heartbeat_ack: false, heartbeat_ref: ref}}
    else
      Logger.warning("Voice heartbeat ACK not received for guild #{state.guild_id}, closing")
      {:close, state}
    end
  end

  def handle_info({:ip_discovery_complete, socket, our_ip, our_port}, state) do
    Logger.info("IP discovery complete: #{our_ip}:#{our_port}")

    select = Payload.select_protocol(our_ip, our_port, state.encryption_mode)

    new_state = %{state | udp_socket: socket}
    {:reply, {:text, Jason.encode!(select)}, new_state}
  end

  # Only process RTP voice packets (payload type 120 = opus), skip RTCP and others
  def handle_info(
        {:udp, _socket, _ip, _port, <<_::8, pt, _::binary>> = packet},
        %{listening: true} = state
      )
      when (pt == 0x78 or pt == 0xF8) and byte_size(packet) >= 12 do
    handle_voice_packet(packet, state)
    {:ok, state}
  end

  def handle_info({:udp, _socket, _ip, _port, _packet}, state), do: {:ok, state}

  def handle_info(_msg, state), do: {:ok, state}

  @impl true
  def terminate(reason, state) do
    Logger.warning(
      "Voice session terminating for guild #{state.guild_id}: reason=#{inspect(reason)} ready=#{state.ready} seq_ack=#{state.seq_ack}"
    )

    :ok
  end

  # Private

  defp handle_voice_packet(packet, state) do
    <<_ver, _type, _seq::16, _ts::32, ssrc::32-big, _rest::binary>> = packet

    case Crypto.decrypt_packet(packet, state.secret_key, state.encryption_mode) do
      {:ok, opus_data} ->
        user_id = Map.get(state.ssrc_map, ssrc)
        opus_data = maybe_dave_decrypt(opus_data, state.dave_manager, user_id)

        EDA.Gateway.Events.dispatch("VOICE_AUDIO", %{
          "guild_id" => state.guild_id,
          "user_id" => user_id,
          "ssrc" => ssrc,
          "opus" => opus_data
        })

      :error ->
        Logger.debug("Decrypt failed size=#{byte_size(packet)} ssrc=#{ssrc}")
    end
  end

  defp maybe_dave_decrypt(opus_data, %Dave.Manager{} = mgr, user_id) when not is_nil(user_id) do
    case Dave.Manager.decrypt_frame(mgr, opus_data, String.to_integer(user_id)) do
      {:ok, decrypted, _updated_mgr} -> decrypted
      {:error, _} -> opus_data
    end
  end

  defp maybe_dave_decrypt(opus_data, _manager, _user_id), do: opus_data

  defp cleanup_state(state) do
    if state.heartbeat_ref, do: Process.cancel_timer(state.heartbeat_ref)
    if state.listening && state.udp_socket, do: :inet.setopts(state.udp_socket, active: false)
    if state.udp_socket, do: :gen_udp.close(state.udp_socket)
  end

  defp build_url(endpoint) do
    "wss://#{endpoint}/?v=8"
  end

  defp handle_event_result({:reply, {:binary, payload}, state}) when is_binary(payload) do
    Logger.debug("Voice WS sending binary payload (#{byte_size(payload)} bytes)")
    {:reply, {:binary, payload}, state}
  end

  defp handle_event_result({:reply, payload, state}) do
    json = Jason.encode!(payload)
    Logger.debug("Voice WS sending: #{json}")
    {:reply, {:text, json}, state}
  end

  defp handle_event_result({:ok, state}) do
    {:ok, state}
  end
end
