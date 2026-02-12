defmodule EDA.Voice.State do
  @moduledoc """
  Holds per-guild voice connection state.
  """

  defstruct [
    :guild_id,
    :channel_id,
    :session_id,
    :token,
    :endpoint,
    :ssrc,
    :secret_key,
    :ip,
    :port,
    :udp_socket,
    :encryption_mode,
    :session_pid,
    :audio_pid,
    sequence: 0,
    timestamp: 0,
    speaking: false,
    paused: false,
    ready: false,
    nonce: 0,
    restart_count: 0
  ]

  @type t :: %__MODULE__{
          guild_id: String.t(),
          channel_id: String.t() | nil,
          session_id: String.t() | nil,
          token: String.t() | nil,
          endpoint: String.t() | nil,
          ssrc: integer() | nil,
          secret_key: binary() | nil,
          ip: String.t() | nil,
          port: integer() | nil,
          udp_socket: port() | nil,
          encryption_mode: String.t() | nil,
          session_pid: pid() | nil,
          audio_pid: pid() | nil,
          sequence: integer(),
          timestamp: integer(),
          speaking: boolean(),
          paused: boolean(),
          ready: boolean(),
          nonce: integer(),
          restart_count: integer()
        }
end
