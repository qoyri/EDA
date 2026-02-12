defmodule EDA.Voice.Session do
  @moduledoc """
  WebSocket connection to a Discord Voice Gateway (one per guild).

  Uses v8 of the voice gateway protocol.
  On 4006 (session invalid), triggers a full restart (leave + rejoin)
  to obtain fresh credentials, matching Nostrum's approach.
  """

  use WebSockex

  require Logger

  alias EDA.Voice.{Event, Payload}

  # 4006 = session no longer valid → restart with fresh credentials
  @restart_close_codes [4006]

  # Other fatal codes → give up, don't reconnect
  @fatal_close_codes [4004, 4009, 4011, 4014, 4016]

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
    seq_ack: 0
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
  def handle_cast({:send_payload, payload}, state) do
    {:reply, {:text, Jason.encode!(payload)}, state}
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

  def handle_info(_msg, state), do: {:ok, state}

  # Private

  defp cleanup_state(state) do
    if state.heartbeat_ref, do: Process.cancel_timer(state.heartbeat_ref)
    if state.udp_socket, do: :gen_udp.close(state.udp_socket)
  end

  defp build_url(endpoint) do
    "wss://#{endpoint}/?v=8"
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
