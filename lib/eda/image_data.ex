defmodule EDA.ImageData do
  @moduledoc """
  Builds the data URIs Discord calls *image data*.

  Avatars, banners, guild icons, emoji and stickers are not uploaded as files: the endpoint
  takes a base64 data URI in the JSON body. Discord accepts PNG, JPEG and GIF there, and the
  media type in the URI has to match the bytes.

      EDA.ImageData.from_path("avatar.png")
      #=> "data:image/png;base64,iVBORw0KGgoAAAANSUhEUg..."

      EDA.API.Member.modify_me(guild_id, avatar: EDA.ImageData.from_path("avatar.png"))

  ## The media type comes from the bytes, not the filename

  A JPEG saved as `photo.png` is a file Discord rejects with an opaque error, and it is an
  easy mistake to make when the image was produced by something else. So the type is read
  from the file's magic number and the extension is ignored:

      iex> EDA.ImageData.type(<<0xFF, 0xD8, 0xFF, 0xE0>>)
      {:ok, :jpeg}

      iex> EDA.ImageData.type("GIF89a" <> <<0>>)
      {:ok, :gif}

  A format Discord does not take — WebP most often, since it is what screenshot tools and
  image editors now default to — is refused here rather than at the API:

      iex> EDA.ImageData.type("RIFF" <> <<0, 0, 0, 0>> <> "WEBP")
      {:error, :webp}

  ## Where this is accepted

  Anywhere Discord's reference says *image data*. `EDA.API.Member.modify_me/2` and
  `EDA.API.User.modify_me/1` also take a raw binary or a path for `:avatar` and `:banner`
  and convert it themselves, so the helper is only needed when building a payload map by
  hand.
  """

  @png <<0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A>>
  @jpeg <<0xFF, 0xD8, 0xFF>>

  @media_types %{png: "image/png", jpeg: "image/jpeg", gif: "image/gif"}

  @typedoc "An image format Discord accepts as image data."
  @type format :: :png | :jpeg | :gif

  @doc """
  Reads an image file and returns its data URI.

  Raises if the file does not exist or is not a format Discord accepts.
  """
  @spec from_path(String.t()) :: String.t()
  def from_path(path) when is_binary(path) do
    unless File.exists?(path) do
      raise ArgumentError, "image does not exist: #{path}"
    end

    path |> File.read!() |> from_binary()
  end

  @doc """
  Returns the data URI for image bytes, detecting the format.

  Raises `ArgumentError` if the bytes are not PNG, JPEG or GIF.

  ## Examples

      iex> EDA.ImageData.from_binary("GIF89a" <> <<1, 2, 3>>)
      "data:image/gif;base64,R0lGODlhAQID"
  """
  @spec from_binary(binary()) :: String.t()
  def from_binary(data) when is_binary(data) do
    case type(data) do
      {:ok, format} ->
        from_binary(data, format)

      {:error, :webp} ->
        raise ArgumentError,
              "Discord does not accept WebP as image data — only PNG, JPEG and GIF. " <>
                "Convert the image first."

      {:error, :unknown} ->
        raise ArgumentError,
              "unrecognised image data: expected PNG, JPEG or GIF. " <>
                "The media type is read from the file's magic number, not its extension."
    end
  end

  @doc """
  Returns the data URI for image bytes, stating the format rather than detecting it.

  Use this only when the bytes genuinely carry no recognisable header; a mismatch between
  the stated type and the data is rejected by Discord, not here.

  ## Examples

      iex> EDA.ImageData.from_binary(<<1, 2, 3>>, :png)
      "data:image/png;base64,AQID"
  """
  @spec from_binary(binary(), format()) :: String.t()
  def from_binary(data, format) when is_binary(data) and is_map_key(@media_types, format) do
    "data:" <> @media_types[format] <> ";base64," <> Base.encode64(data)
  end

  def from_binary(data, format) when is_binary(data) do
    raise ArgumentError,
          "#{inspect(format)} is not an image data format Discord accepts, expected one of " <>
            inspect(Map.keys(@media_types))
  end

  @doc """
  Identifies image bytes by their magic number.

  Returns `{:ok, format}`, or `{:error, :webp}` / `{:error, :unknown}` for something Discord
  will not take.

  ## Examples

      iex> EDA.ImageData.type(<<0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A>>)
      {:ok, :png}

      iex> EDA.ImageData.type("not an image")
      {:error, :unknown}
  """
  @spec type(binary()) :: {:ok, format()} | {:error, :webp | :unknown}
  def type(@png <> _rest), do: {:ok, :png}
  def type(@jpeg <> _rest), do: {:ok, :jpeg}
  def type("GIF87a" <> _rest), do: {:ok, :gif}
  def type("GIF89a" <> _rest), do: {:ok, :gif}
  def type(<<"RIFF", _size::binary-size(4), "WEBP", _rest::binary>>), do: {:error, :webp}
  def type(data) when is_binary(data), do: {:error, :unknown}

  @doc """
  Returns `true` if the string is already a data URI.

  ## Examples

      iex> EDA.ImageData.data_uri?("data:image/png;base64,AQID")
      true

      iex> EDA.ImageData.data_uri?("avatar.png")
      false
  """
  @spec data_uri?(term()) :: boolean()
  def data_uri?("data:image/" <> _rest), do: true
  def data_uri?(_other), do: false

  @doc """
  Coerces whatever an API caller passed for an image field into a data URI.

  This is what lets `:avatar` and `:banner` take a path, raw bytes or a ready-made URI. A
  data URI is returned as is, and `nil` passes through because Discord uses it to *clear*
  an avatar or banner.

  A binary is ambiguous — it could be a path or the image itself — so it is read as image
  bytes when it carries a recognisable header, and as a path only when it still looks like
  one. Neither, and it raises here rather than sending something Discord cannot use.

  ## Examples

      iex> EDA.ImageData.coerce(nil)
      nil

      iex> EDA.ImageData.coerce("data:image/png;base64,AQID")
      "data:image/png;base64,AQID"

      iex> EDA.ImageData.coerce("GIF89a" <> <<1, 2, 3>>)
      "data:image/gif;base64,R0lGODlhAQID"
  """
  @spec coerce(nil | String.t() | binary()) :: nil | String.t()
  def coerce(nil), do: nil

  def coerce(value) when is_binary(value) do
    cond do
      data_uri?(value) -> value
      match?({:ok, _}, type(value)) -> from_binary(value)
      # from_binary/1 carries the message that names the format
      match?({:error, :webp}, type(value)) -> from_binary(value)
      path?(value) -> from_path(value)
      true -> from_binary(value)
    end
  end

  # Long, non-printable or multi-line input is image data that EDA failed to identify, not a
  # filename — saying "image does not exist" about a megabyte of bytes helps nobody.
  @max_path_length 4096

  defp path?(value) do
    byte_size(value) <= @max_path_length and String.valid?(value) and
      not String.contains?(value, ["\n", "\r", <<0>>])
  end
end
