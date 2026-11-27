defmodule EDA.Voice.Payload do
  @moduledoc """
  Voice Gateway JSON payload builders (v8).

  Voice Gateway opcodes:
  - 0: IDENTIFY
  - 1: SELECT_PROTOCOL
  - 3: HEARTBEAT
  - 5: SPEAKING
  - 7: RESUME
  - 15: MEDIA_SINK_WANTS
  """

  @doc """
  Builds an IDENTIFY payload for voice gateway authentication.

  When `dave_version` is > 0, includes DAVE protocol negotiation using
  `max_dave_protocol_version`.
  """
  def identify(server_id, user_id, session_id, token, dave_version \\ 0) do
    d = %{
      server_id: server_id,
      user_id: user_id,
      session_id: session_id,
      token: token
    }

    d =
      if dave_version > 0 do
        Map.put(d, :max_dave_protocol_version, dave_version)
      else
        d
      end

    %{op: 0, d: d}
  end

  @doc """
  Builds a SELECT_PROTOCOL payload with our IP discovery results and encryption mode.
  """
  def select_protocol(ip, port, mode) do
    %{
      op: 1,
      d: %{
        protocol: "udp",
        data: %{
          address: ip,
          port: port,
          mode: mode
        }
      }
    }
  end

  @doc """
  Builds a HEARTBEAT payload with the given nonce and seq_ack.
  """
  def heartbeat(nonce, seq_ack \\ 0) do
    %{op: 3, d: %{t: nonce, seq_ack: seq_ack}}
  end

  @doc """
  Builds a SPEAKING payload.

  Flags:
  - 1: Microphone (normal voice)
  - 2: Soundshare (go live / screen share audio)
  - 4: Priority speaker
  """
  def speaking(ssrc, speaking \\ true) do
    flags = if speaking, do: 1, else: 0

    %{
      op: 5,
      d: %{
        speaking: flags,
        delay: 0,
        ssrc: ssrc
      }
    }
  end

  @doc """
  Builds a RESUME payload for reconnecting to the voice gateway.
  """
  def resume(server_id, session_id, token) do
    %{
      op: 7,
      d: %{
        server_id: server_id,
        session_id: session_id,
        token: token
      }
    }
  end

  @doc """
  Builds a MEDIA_SINK_WANTS payload (OP 15): which users' voice the server should send.

  `wants` maps an SSRC, or `:any` for every SSRC not listed, to `0` (do not send) through
  `100` (send). The payload replaces the previous one whole.
  """
  def media_sink_wants(wants) when is_map(wants) do
    %{op: 15, d: Map.new(wants, fn {ssrc, value} -> {to_string(ssrc), value} end)}
  end

  # DAVE (E2EE) Opcodes

  @doc """
  Builds a DAVE_MLS_KEY_PACKAGE payload (OP 26).

  Per DAVE spec this opcode is sent as a binary frame:
  `<<26, mls_key_package::binary>>`.
  """
  def dave_mls_key_package(key_package_bytes) do
    {:binary, <<26, key_package_bytes::binary>>}
  end

  @doc """
  Builds a DAVE_READY_FOR_TRANSITION payload (OP 23).

  Confirms to the gateway that the client is ready for the protocol/epoch transition.
  """
  def dave_ready_for_transition(transition_id) do
    %{op: 23, d: %{transition_id: transition_id}}
  end

  @doc """
  Builds a DAVE_MLS_COMMIT_WELCOME payload (OP 28).

  Per DAVE spec this opcode is sent as a binary frame:
  `<<28, commit::binary, welcome::binary>>` where welcome is optional.
  """
  def dave_mls_commit_welcome(commit_bytes, welcome_bytes \\ nil) do
    welcome = if is_binary(welcome_bytes), do: welcome_bytes, else: <<>>
    {:binary, <<28, commit_bytes::binary, welcome::binary>>}
  end

  @doc """
  Builds a DAVE_MLS_INVALID_COMMIT_WELCOME payload (OP 31).

  Sent when the client cannot process a commit or welcome, triggering
  the gateway to remove and re-add the member.
  """
  def dave_mls_invalid_commit_welcome(transition_id) do
    %{op: 31, d: %{transition_id: transition_id}}
  end
end
