defmodule EDA.Voice.Event do
  @moduledoc """
  Handles Voice Gateway events received by `EDA.Voice.Session`.

  Voice Gateway opcodes (receive):
  - 2: READY
  - 4: SESSION_DESCRIPTION
  - 6: HEARTBEAT_ACK
  - 8: HELLO
  """

  require Logger

  alias EDA.Voice.{Audio, Crypto, Dave, Payload}

  @doc """
  Handles a decoded voice gateway payload and returns updated state.
  """
  def handle(%{"op" => 8, "d" => %{"heartbeat_interval" => raw_interval}}, state) do
    # HELLO - start heartbeat and send IDENTIFY
    interval = trunc(raw_interval)
    Logger.debug("Voice Gateway HELLO, heartbeat interval: #{interval}ms")

    jitter = :rand.uniform(max(round(interval * 0.1), 1))
    ref = Process.send_after(self(), :voice_heartbeat, interval - jitter)

    me = EDA.Cache.me()
    user_id = me["id"]

    Logger.debug(
      "Voice IDENTIFY: server=#{state.guild_id} user=#{user_id} " <>
        "session=#{state.session_id} token=#{String.slice(state.token || "", 0..7)}..."
    )

    dave_version = dave_version()

    identify =
      Payload.identify(
        state.guild_id,
        user_id,
        state.session_id,
        state.token,
        dave_version
      )

    {:reply, identify, %{state | heartbeat_interval: interval, heartbeat_ref: ref}}
  end

  def handle(%{"op" => 2, "d" => data}, state) do
    # READY - received SSRC, IP, port; start IP discovery
    ssrc = data["ssrc"]
    ip = data["ip"]
    port = data["port"]
    modes = data["modes"] || []

    Logger.info("Voice READY: ssrc=#{ssrc}, ip=#{ip}, port=#{port}")

    case Crypto.select_mode(modes) do
      {:ok, mode} ->
        Logger.debug("Selected encryption mode: #{mode}")

        new_state = %{state | ssrc: ssrc, encryption_mode: mode, ip: ip, port: port}
        start_ip_discovery(ip, port, ssrc)
        {:ok, new_state}

      :error ->
        Logger.error("No supported encryption mode. Available: #{inspect(modes)}")
        {:ok, state}
    end
  end

  def handle(%{"op" => 4, "d" => data}, state) do
    # SESSION_DESCRIPTION - we have the secret key, voice is ready!
    secret_key = data["secret_key"] |> :erlang.list_to_binary()
    mode = data["mode"]

    dave_version =
      get_in(data, ["dave", "protocol_version"]) ||
        data["dave_protocol_version"] ||
        0

    Logger.info(
      "Voice session established, encryption: #{mode}" <>
        if(dave_version > 0, do: ", DAVE v#{dave_version}", else: "")
    )

    new_state = %{state | secret_key: secret_key, encryption_mode: mode, ready: true}

    # Initialize DAVE manager if E2EE is negotiated
    new_state =
      if dave_version > 0 do
        me = EDA.Cache.me()
        user_id = String.to_integer(me["id"])
        channel_id = String.to_integer(state.channel_id)

        dave_manager =
          Dave.Manager.new(dave_version, user_id, channel_id)

        %{new_state | dave_manager: dave_manager}
      else
        new_state
      end

    # Notify the Voice GenServer that we're ready BEFORE dispatching to the
    # consumer, so that start_listening/play calls from the consumer handler
    # see ready: true (avoids race condition).
    EDA.Voice.voice_ready(state.guild_id, new_state)

    # Dispatch VOICE_READY event to the consumer
    EDA.Gateway.Events.dispatch("VOICE_READY", %{
      "guild_id" => state.guild_id,
      "channel_id" => state.channel_id
    })

    # Per DAVE flow, send our key package after SESSION_DESCRIPTION indicates
    # DAVE support. We still also handle OP25-triggered key package sends.
    if dave_version > 0 do
      case Dave.Manager.key_package_payload(new_state.dave_manager) do
        {:ok, payload} ->
          Logger.debug("DAVE: Sending initial MLS key package after SESSION_DESCRIPTION")
          {:reply, payload, new_state}

        :error ->
          {:ok, new_state}
      end
    else
      {:ok, new_state}
    end
  end

  def handle(%{"op" => 6}, state) do
    # HEARTBEAT_ACK
    Logger.debug("Voice heartbeat ACK")
    {:ok, %{state | heartbeat_ack: true}}
  end

  def handle(%{"op" => 9}, state) do
    # RESUMED
    Logger.info("Voice session resumed")
    {:ok, state}
  end

  def handle(%{"op" => 5, "d" => data}, state) do
    # SPEAKING — maps SSRC to user_id and notifies when users start/stop speaking
    ssrc = data["ssrc"]
    user_id = data["user_id"]
    speaking = data["speaking"]

    new_ssrc_map = Map.put(state.ssrc_map, ssrc, user_id)

    event = if speaking > 0, do: "VOICE_SPEAKING_START", else: "VOICE_SPEAKING_STOP"

    EDA.Gateway.Events.dispatch(event, %{
      "guild_id" => state.guild_id,
      "user_id" => user_id,
      "ssrc" => ssrc
    })

    {:ok, %{state | ssrc_map: new_ssrc_map}}
  end

  # OP 11: CLIENTS_CONNECT — track connected voice clients for DAVE proposals
  def handle(%{"op" => 11, "d" => %{"user_ids" => user_ids}}, state) when is_list(user_ids) do
    ids = Enum.map(user_ids, &to_string/1)
    new_clients = Enum.reduce(ids, state.connected_clients, &MapSet.put(&2, &1))
    Logger.debug("DAVE: Clients connected: #{inspect(ids)}")
    {:ok, %{state | connected_clients: new_clients}}
  end

  # OP 12: CLIENTS_DISCONNECT (batch) — remove disconnected voice clients
  def handle(%{"op" => 12, "d" => %{"user_ids" => user_ids}}, state) when is_list(user_ids) do
    ids = Enum.map(user_ids, &to_string/1)
    new_clients = Enum.reduce(ids, state.connected_clients, &MapSet.delete(&2, &1))
    Logger.debug("DAVE: Clients disconnected: #{inspect(ids)}")
    {:ok, %{state | connected_clients: new_clients}}
  end

  # OP 13: CLIENT_DISCONNECT (single) — per DAVE spec, single user_id disconnect
  def handle(%{"op" => 13, "d" => %{"user_id" => user_id}}, state) when not is_nil(user_id) do
    id = to_string(user_id)
    new_clients = MapSet.delete(state.connected_clients, id)
    Logger.debug("DAVE: Client disconnected: #{id}")
    {:ok, %{state | connected_clients: new_clients}}
  end

  def handle(%{"op" => 13, "d" => data}, state) do
    Logger.debug("DAVE: Client disconnect (unhandled format): #{inspect(data)}")
    {:ok, state}
  end

  # DAVE opcodes 21-31 — delegate to Dave.Manager
  def handle(%{"op" => op, "d" => data}, %{dave_manager: %Dave.Manager{}} = state)
      when op in 21..31 do
    data =
      if op == 27 do
        Map.put(data, "connected_clients", state.connected_clients)
      else
        data
      end

    {updated_manager, replies} = Dave.Manager.handle_mls_event(state.dave_manager, op, data)
    new_state = %{state | dave_manager: updated_manager}

    if Dave.Manager.transitioned_to_dave?(state.dave_manager, updated_manager) do
      EDA.Gateway.Events.dispatch("VOICE_DAVE_READY", %{
        "guild_id" => state.guild_id,
        "channel_id" => state.channel_id
      })
    end

    case replies do
      [first | rest] ->
        # Send additional payloads directly (WebSockex only replies with one frame)
        Enum.each(rest, fn payload ->
          EDA.Voice.Session.send_payload(state.guild_id, payload)
        end)

        {:reply, first, new_state}

      [] ->
        {:ok, new_state}
    end
  end

  def handle(payload, state) do
    Logger.debug("Unhandled voice payload: #{inspect(payload)}")
    {:ok, state}
  end

  defp start_ip_discovery(ip, port, ssrc) do
    session_pid = self()

    spawn_link(fn ->
      case Audio.open_udp_and_discover(ip, port, ssrc) do
        {:ok, socket, our_ip, our_port} ->
          # Transfer socket ownership to the Session process before this
          # spawned process exits, otherwise Erlang closes the socket.
          :gen_udp.controlling_process(socket, session_pid)
          send(session_pid, {:ip_discovery_complete, socket, our_ip, our_port})

        {:error, reason} ->
          Logger.error("IP discovery failed: #{inspect(reason)}")
      end
    end)
  end

  # Advertising DAVE commits the session to MLS: Discord will expect end-to-end encrypted
  # media. Without the NIF that cannot be honoured, so it is only advertised when it can be.
  #
  # Discord refuses voice without DAVE outside Stage channels (close code 4017), so connecting
  # without it deserves a warning in both cases — including the default, where `:dave` is not
  # set at all and nothing used to be said until the connection was refused. Once per VM: it is
  # configuration advice, not an event, and a bot may join many channels.
  @voice_docs "https://hexdocs.pm/eda/readme.html#voice"

  defp dave_version do
    cond do
      not Application.get_env(:eda, :dave, false) ->
        warn_once(
          :dave_disabled,
          "[EDA] Connecting to voice without DAVE, because config :eda, dave is not enabled. " <>
            "Discord refuses voice without DAVE end-to-end encryption everywhere but Stage " <>
            "channels (close code 4017). See #{@voice_docs}"
        )

        0

      EDA.Voice.Dave.Native.available?() ->
        1

      true ->
        warn_once(
          :dave_nif_missing,
          "[EDA] config :eda, dave: true, but the DAVE NIF is not available — add " <>
            "{:rustler, \"~> 0.35\"} to your deps and install a Rust toolchain. " <>
            "Discord requires DAVE for voice everywhere but Stage channels, so this " <>
            "connection will be refused with close code 4017. See #{@voice_docs}"
        )

        0
    end
  end

  @doc false
  # Clears the once-per-VM flags, so tests can observe the warnings deterministically.
  def reset_dave_warnings do
    for key <- [:dave_disabled, :dave_nif_missing], do: :persistent_term.erase({__MODULE__, key})
    :ok
  end

  defp warn_once(key, message) do
    unless :persistent_term.get({__MODULE__, key}, false) do
      :persistent_term.put({__MODULE__, key}, true)
      Logger.warning(message)
    end
  end
end
