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

  alias EDA.Voice.{Audio, Crypto, Payload}

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

    identify =
      Payload.identify(
        state.guild_id,
        user_id,
        state.session_id,
        state.token
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

    Logger.info("Voice session established, encryption: #{mode}")

    new_state = %{state | secret_key: secret_key, encryption_mode: mode, ready: true}

    # Dispatch VOICE_READY event to the consumer
    EDA.Gateway.Events.dispatch("VOICE_READY", %{
      "guild_id" => state.guild_id,
      "channel_id" => state.channel_id
    })

    # Notify the Voice GenServer that we're ready
    EDA.Voice.voice_ready(state.guild_id, new_state)

    {:ok, new_state}
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
end
