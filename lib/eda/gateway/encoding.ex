defmodule EDA.Gateway.Encoding do
  @moduledoc """
  Behaviour for encoding/decoding Discord Gateway payloads.

  Two implementations are provided:

  - `EDA.Gateway.Encoding.ETF` (default) — Erlang External Term Format.
    Binary encoding decoded natively by the BEAM via `:erlang.binary_to_term/1`.
    Payloads are ~15-30% smaller than JSON and decode significantly faster.

  - `EDA.Gateway.Encoding.JSON` — JSON via `Jason`.
    Text-based, useful for debugging or when ETF is undesirable.

  ## Configuration

      config :eda, gateway_encoding: :etf   # default
      config :eda, gateway_encoding: :json

  ## Interaction with compression

  Both encodings work with either transport compression (`EDA.Gateway.Compression`). The
  gateway connection decompresses frames before passing them to `decode/1`, so the encoding
  module always receives raw (uncompressed) binary data.
  """

  @doc "Decodes a raw gateway payload binary into a map with string keys."
  @callback decode(binary()) :: map()

  @doc """
  Encodes a map into a gateway payload ready to send over WebSocket.

  Returns `{:text, binary()}` for JSON or `{:binary, binary()}` for ETF,
  matching the frame types expected by `WebSockex`.
  """
  @callback encode(map()) :: {:text | :binary, binary()}

  @doc "Returns the encoding name for the gateway URL query parameter (`\"json\"` or `\"etf\"`)."
  @callback url_encoding() :: String.t()

  @doc """
  Returns the configured encoding module.

  Reads `:gateway_encoding` from the `:eda` application config.
  Defaults to `EDA.Gateway.Encoding.ETF`.
  """
  @spec module() :: module()
  def module do
    case Application.get_env(:eda, :gateway_encoding, :etf) do
      :etf -> EDA.Gateway.Encoding.ETF
      :json -> EDA.Gateway.Encoding.JSON
    end
  end
end
