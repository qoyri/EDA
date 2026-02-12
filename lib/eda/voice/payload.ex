defmodule EDA.Voice.Payload do
  @moduledoc """
  Voice Gateway JSON payload builders (v8).

  Voice Gateway opcodes:
  - 0: IDENTIFY
  - 1: SELECT_PROTOCOL
  - 3: HEARTBEAT
  - 5: SPEAKING
  - 7: RESUME
  """

  @doc """
  Builds an IDENTIFY payload for voice gateway authentication.
  """
  def identify(server_id, user_id, session_id, token) do
    %{
      op: 0,
      d: %{
        server_id: server_id,
        user_id: user_id,
        session_id: session_id,
        token: token
      }
    }
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
end
