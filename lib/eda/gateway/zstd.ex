defmodule EDA.Gateway.Zstd do
  @moduledoc """
  Zstd-stream decompressor for Discord gateway transport compression.

  Holds one zstd decompression context for the lifetime of a gateway connection. Discord flushes
  the stream at the end of every message, so each WebSocket message decompresses to one complete
  payload; there is no suffix to wait for, as there is with zlib.

  Measured on the frames Discord sent to a real bot, it decompresses the same payloads in 28 % of
  the time `EDA.Gateway.Zlib` takes. It needs EDA's NIF, the one that also carries DAVE; without
  it, `EDA.Gateway.Compression` falls back to zlib.

  Same interface as `EDA.Gateway.Zlib`:

      {:ok, zstd} = EDA.Gateway.Zstd.init()

      case EDA.Gateway.Zstd.push(zstd, binary_frame) do
        {:ok, payload, zstd}   -> # a complete message
        {:incomplete, zstd}    -> # nothing decompressed yet
        {:error, reason, zstd} -> # decompression failed, context was reset
      end
  """

  alias EDA.Voice.Dave.Native

  # Frames above this go to a dirty scheduler: about 300 KB once decompressed, 0.1 ms of work.
  # Nearly every event is far below it; a large GUILD_CREATE or READY is not.
  @dirty_threshold 32 * 1024

  defstruct [:context]

  @type t :: %__MODULE__{context: reference()}

  @doc "Returns true when EDA's NIF is loaded, so zstd-stream can be used."
  @spec available?() :: boolean()
  def available? do
    match?({:ok, _}, Native.zstd_new())
  rescue
    _ -> false
  end

  @doc "Creates a decompressor with a fresh zstd context."
  @spec init() :: {:ok, t()}
  def init do
    {:ok, context} = Native.zstd_new()
    {:ok, %__MODULE__{context: context}}
  end

  @doc """
  Decompresses one WebSocket message.

  Returns:
  - `{:ok, decompressed_binary, zstd}` — a complete message was decompressed
  - `{:incomplete, zstd}` — the frame produced no output yet
  - `{:error, reason, zstd}` — decompression failed, context has been reset
  """
  @spec push(t(), binary()) :: {:ok, binary(), t()} | {:incomplete, t()} | {:error, term(), t()}
  def push(%__MODULE__{context: context} = state, frame) when is_binary(frame) do
    result =
      if byte_size(frame) > @dirty_threshold,
        do: Native.zstd_decompress_dirty(context, frame),
        else: Native.zstd_decompress(context, frame)

    case result do
      {:ok, <<>>} ->
        {:incomplete, state}

      {:ok, payload} ->
        {:ok, payload, state}

      {:error, reason} ->
        :telemetry.execute([:eda, :gateway, :zstd, :error], %{}, %{reason: reason})
        {:error, :decompress_failed, reset(state)}
    end
  end

  @doc "Resets the context. Call this when reconnecting to the gateway."
  @spec reset(t()) :: t()
  def reset(%__MODULE__{context: context} = state) do
    Native.zstd_reset(context)
    state
  end

  @doc "Releases the context. The garbage collector frees it with its last reference."
  @spec close(t()) :: :ok
  def close(%__MODULE__{}), do: :ok
end
