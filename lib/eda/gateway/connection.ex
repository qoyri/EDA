defmodule EDA.Gateway.Connection do
  @moduledoc """
  WebSocket connection to Discord Gateway.

  Handles:
  - WebSocket connection lifecycle
  - Heartbeat management
  - Event reception and dispatch
  - Resume/reconnect logic
  """

  use WebSockex

  require Logger

  alias EDA.Gateway.{Events, Heartbeat}

  @gateway_url "wss://gateway.discord.gg/?v=10&encoding=json"

  defstruct [
    :token,
    :session_id,
    :resume_gateway_url,
    :heartbeat_interval,
    :heartbeat_ref,
    :seq,
    :heartbeat_ack,
    :shard
  ]

  @type t :: %__MODULE__{
          token: String.t(),
          session_id: String.t() | nil,
          resume_gateway_url: String.t() | nil,
          heartbeat_interval: integer() | nil,
          heartbeat_ref: reference() | nil,
          seq: integer() | nil,
          heartbeat_ack: boolean(),
          shard: {integer(), integer()}
        }

  # Client API

  @doc """
  Starts the Gateway connection.
  """
  def start_link(opts) do
    token = Keyword.fetch!(opts, :token)

    state = %__MODULE__{
      token: token,
      seq: nil,
      heartbeat_ack: true,
      shard: {0, 1}
    }

    WebSockex.start_link(@gateway_url, __MODULE__, state, name: __MODULE__)
  end

  @doc """
  Sends a message to a channel. Convenience function.
  """
  def send_message(channel_id, content) do
    EDA.REST.Client.create_message(channel_id, content)
  end

  @doc """
  Sends OP 4 (Voice State Update) to join/leave a voice channel.

  Set `channel_id` to `nil` to leave the voice channel.
  """
  def update_voice_state(guild_id, channel_id, opts) do
    WebSockex.cast(__MODULE__, {:update_voice_state, guild_id, channel_id, opts})
  end

  # WebSockex Callbacks

  @impl true
  def handle_connect(_conn, state) do
    Logger.info("Connected to Discord Gateway")
    {:ok, state}
  end

  @impl true
  def handle_disconnect(%{reason: reason}, state) do
    Logger.warning("Disconnected from Gateway: #{inspect(reason)}")

    # Try to resume if we have session info
    if state.session_id && state.resume_gateway_url do
      Logger.info("Will attempt to resume session")
      {:reconnect, state}
    else
      {:reconnect, %{state | session_id: nil, seq: nil}}
    end
  end

  @impl true
  def handle_frame({:text, payload}, state) do
    payload
    |> Jason.decode!()
    |> handle_payload(state)
  end

  def handle_frame(_frame, state), do: {:ok, state}

  @impl true
  def handle_cast({:heartbeat}, state) do
    send_heartbeat(state)
  end

  def handle_cast({:update_voice_state, guild_id, channel_id, opts}, state) do
    payload = %{
      op: 4,
      d: %{
        guild_id: guild_id,
        channel_id: channel_id,
        self_mute: Keyword.get(opts, :mute, false),
        self_deaf: Keyword.get(opts, :deaf, false)
      }
    }

    {:reply, {:text, Jason.encode!(payload)}, state}
  end

  @impl true
  def handle_info({:heartbeat}, state) do
    if state.heartbeat_ack do
      send_heartbeat(%{state | heartbeat_ack: false})
    else
      Logger.warning("Heartbeat ACK not received, reconnecting...")
      {:close, state}
    end
  end

  def handle_info(_msg, state), do: {:ok, state}

  # Payload Handling

  defp handle_payload(%{"op" => 10, "d" => %{"heartbeat_interval" => interval}}, state) do
    Logger.debug("Received HELLO, heartbeat interval: #{interval}ms")

    # Start heartbeat
    ref = Heartbeat.start(interval)

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
    Logger.debug("Received Heartbeat ACK")
    {:ok, %{state | heartbeat_ack: true}}
  end

  # Dispatch event
  defp handle_payload(%{"op" => 0, "t" => event_type, "s" => seq, "d" => data}, state) do
    new_state = %{state | seq: seq}

    case event_type do
      "READY" ->
        handle_ready(data, new_state)

      "RESUMED" ->
        Logger.info("Successfully resumed session")
        {:ok, new_state}

      _ ->
        # Dispatch to consumer
        Events.dispatch(event_type, data)
        {:ok, new_state}
    end
  end

  # Reconnect request
  defp handle_payload(%{"op" => 7}, state) do
    Logger.info("Gateway requested reconnect")
    {:close, state}
  end

  # Invalid session
  defp handle_payload(%{"op" => 9, "d" => resumable}, state) do
    Logger.warning("Invalid session, resumable: #{resumable}")

    if resumable do
      Process.sleep(1000 + :rand.uniform(5000))
      {:close, state}
    else
      {:close, %{state | session_id: nil, seq: nil}}
    end
  end

  defp handle_payload(payload, state) do
    Logger.debug("Unhandled payload: #{inspect(payload)}")
    {:ok, state}
  end

  # Event Handlers

  defp handle_ready(data, state) do
    session_id = data["session_id"]
    resume_url = data["resume_gateway_url"]
    user = data["user"]

    Logger.info("Bot ready as #{user["username"]}##{user["discriminator"]}")

    # Store current user in cache
    EDA.Cache.put_me(user)

    # Dispatch READY event
    Events.dispatch("READY", data)

    {:ok, %{state | session_id: session_id, resume_gateway_url: resume_url}}
  end

  # Sending Payloads

  defp send_identify(state) do
    {os, _} = :os.type()

    payload = %{
      op: 2,
      d: %{
        token: state.token,
        intents: EDA.intents(),
        properties: %{
          os: to_string(os),
          browser: "EDA",
          device: "EDA"
        },
        shard: Tuple.to_list(state.shard)
      }
    }

    Logger.debug("Sending IDENTIFY")
    {:reply, {:text, Jason.encode!(payload)}, state}
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

    Logger.debug("Sending RESUME")
    {:reply, {:text, Jason.encode!(payload)}, state}
  end

  defp send_heartbeat(state) do
    payload = %{op: 1, d: state.seq}
    Logger.debug("Sending heartbeat (seq: #{state.seq})")

    # Schedule next heartbeat
    ref = Heartbeat.start(state.heartbeat_interval)

    {:reply, {:text, Jason.encode!(payload)}, %{state | heartbeat_ref: ref}}
  end
end
