defmodule EDA.Gateway.Encoding.JSON do
  @moduledoc """
  JSON encoding for Discord Gateway payloads via `Jason`.

  Text-based format useful for debugging. Payloads are slightly larger
  than ETF and decoding is slower, but the output is human-readable.
  """

  @behaviour EDA.Gateway.Encoding

  @doc "Decodes a JSON binary into a map with string keys."
  @impl true
  @spec decode(binary()) :: map()
  def decode(binary) do
    # Strings are copied out of the frame. By default they only reference it, so a cached member's
    # name would keep its whole GUILD_CREATE, often hundreds of kilobytes, alive.
    Jason.decode!(binary, strings: :copy)
  end

  @doc "Encodes a map as a JSON text frame."
  @impl true
  @spec encode(map()) :: {:text, binary()}
  def encode(map) do
    {:text, Jason.encode!(map)}
  end

  @doc ~s[Returns `"json"` for the gateway URL query parameter.]
  @impl true
  @spec url_encoding() :: String.t()
  def url_encoding, do: "json"
end
