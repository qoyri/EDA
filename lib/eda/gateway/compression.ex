defmodule EDA.Gateway.Compression do
  @moduledoc """
  Chooses the gateway's transport compression.

  - `EDA.Gateway.Zstd` (default when EDA's NIF is loaded) — `zstd-stream`.
  - `EDA.Gateway.Zlib` — `zlib-stream`, in the BEAM's own zlib.

  Both compress Discord's payloads to about the same size; zstd decompresses them in about a
  quarter of the time. It runs in EDA's NIF, the precompiled one that also carries DAVE, so a bot
  without it falls back to zlib.

  ## Configuration

      config :eda, gateway_compression: :zstd   # default, zlib when the NIF is not loaded
      config :eda, gateway_compression: :zlib
  """

  require Logger

  @doc """
  Returns the decompressor module to use: `EDA.Gateway.Zstd` or `EDA.Gateway.Zlib`.
  """
  @spec module() :: module()
  def module do
    case Application.get_env(:eda, :gateway_compression, :zstd) do
      :zlib ->
        EDA.Gateway.Zlib

      :zstd ->
        if EDA.Gateway.Zstd.available?() do
          EDA.Gateway.Zstd
        else
          Logger.warning(
            "[EDA] zstd-stream needs EDA's NIF, which is not loaded; the gateway uses zlib-stream"
          )

          EDA.Gateway.Zlib
        end
    end
  end

  @doc ~s[Returns the `compress` query parameter for a decompressor module.]
  @spec url_param(module()) :: String.t()
  def url_param(EDA.Gateway.Zstd), do: "zstd-stream"
  def url_param(EDA.Gateway.Zlib), do: "zlib-stream"
end
