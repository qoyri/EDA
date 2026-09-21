defmodule EDA.SoundData do
  @moduledoc """
  Builds the data URI a soundboard sound is uploaded as.

  A guild soundboard sound is not uploaded as a file: `POST /guilds/{id}/soundboard-sounds`
  takes the audio as a base64 data URI in the JSON body, the way an avatar takes *image data*.
  Discord accepts MP3 and Ogg there, up to 512 KiB and 5.2 seconds.

      EDA.SoundData.from_path("airhorn.mp3")
      #=> "data:audio/mpeg;base64,SUQzBAAAAAAAI1RTU0UAAAAPAAADTGF2..."

  `EDA.API.Soundboard.create/2` takes a path or raw bytes for `:sound` and converts them
  itself, so this is only needed when building a payload by hand.

  ## The format comes from the bytes, not the filename

  As with `EDA.ImageData`, the media type is read from the audio's own header and the
  extension is ignored, so a WAV saved as `sound.mp3` is refused here instead of by Discord:

      iex> EDA.SoundData.type("ID3" <> <<4, 0, 0>>)
      {:ok, :mp3}

      iex> EDA.SoundData.type("OggS" <> <<0>>)
      {:ok, :ogg}

      iex> EDA.SoundData.type("RIFF" <> <<0, 0, 0, 0>> <> "WAVE")
      {:error, :unknown}

  The size limit is checked too. The 5.2-second limit is not: measuring it means decoding the
  audio, and Discord reports it clearly enough.
  """

  import Bitwise

  @max_bytes 512 * 1024

  @media_types %{mp3: "audio/mpeg", ogg: "audio/ogg"}

  @typedoc "An audio format Discord accepts for a soundboard sound."
  @type format :: :mp3 | :ogg

  @doc "The largest sound Discord accepts, in bytes."
  @spec max_bytes() :: pos_integer()
  def max_bytes, do: @max_bytes

  @doc """
  Reads an audio file and returns its data URI.

  Raises if the file does not exist, is not MP3 or Ogg, or is over the size limit.
  """
  @spec from_path(String.t()) :: String.t()
  def from_path(path) when is_binary(path) do
    unless File.exists?(path) do
      raise ArgumentError, "sound file does not exist: #{path}"
    end

    path |> File.read!() |> from_binary()
  end

  @doc """
  Encodes audio bytes as a data URI, identifying MP3 or Ogg from the header.

  Raises if the format is not one Discord accepts or the sound is over the size limit.
  """
  @spec from_binary(binary()) :: String.t()
  def from_binary(data) when is_binary(data) do
    if byte_size(data) > @max_bytes do
      raise ArgumentError,
            "a soundboard sound is at most #{div(@max_bytes, 1024)} KiB, got " <>
              "#{Float.round(byte_size(data) / 1024, 1)} KiB"
    end

    case type(data) do
      {:ok, format} ->
        "data:#{Map.fetch!(@media_types, format)};base64,#{Base.encode64(data)}"

      {:error, :unknown} ->
        raise ArgumentError,
              "a soundboard sound must be MP3 or Ogg; these bytes are neither. " <>
                "The format is read from the audio's header, not its extension."
    end
  end

  @doc """
  Identifies MP3 or Ogg audio by its header.

  MP3 is recognised by an ID3v2 tag or, for an untagged file, by the MPEG frame sync that
  opens it.

      iex> EDA.SoundData.type(<<0xFF, 0xFB, 0x90, 0x00>>)
      {:ok, :mp3}
  """
  @spec type(binary()) :: {:ok, format()} | {:error, :unknown}
  def type("ID3" <> _rest), do: {:ok, :mp3}
  def type("OggS" <> _rest), do: {:ok, :ogg}
  def type(<<0xFF, second, _rest::binary>>) when (second &&& 0xE0) == 0xE0, do: {:ok, :mp3}
  def type(data) when is_binary(data), do: {:error, :unknown}

  @doc """
  Returns true for a data URI Discord would take as a sound.

      iex> EDA.SoundData.data_uri?("data:audio/ogg;base64,T2dnUw==")
      true

      iex> EDA.SoundData.data_uri?("data:image/png;base64,AQID")
      false
  """
  @spec data_uri?(term()) :: boolean()
  def data_uri?("data:audio/" <> _rest), do: true
  def data_uri?(_other), do: false

  @doc """
  Coerces what a caller passed for `:sound` into a data URI: a ready-made URI is returned as
  is, recognisable audio bytes are encoded, and anything else is read as a path.

      iex> EDA.SoundData.coerce("data:audio/mpeg;base64,SUQz")
      "data:audio/mpeg;base64,SUQz"

      iex> EDA.SoundData.coerce("OggS")
      "data:audio/ogg;base64,T2dnUw=="
  """
  @spec coerce(String.t() | binary()) :: String.t()
  def coerce(value) when is_binary(value) do
    cond do
      data_uri?(value) -> value
      match?({:ok, _}, type(value)) -> from_binary(value)
      path?(value) -> from_path(value)
      true -> from_binary(value)
    end
  end

  # Long, non-printable or multi-line input is audio EDA failed to identify, not a filename.
  @max_path_length 4096

  defp path?(value) do
    byte_size(value) <= @max_path_length and String.valid?(value) and
      not String.contains?(value, ["\n", "\r", <<0>>])
  end
end
