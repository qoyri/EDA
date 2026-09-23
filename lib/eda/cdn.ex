defmodule EDA.CDN do
  @moduledoc false
  # Builds image URLs on Discord's CDN, for the entity helpers (`EDA.User.avatar_url/2`,
  # `EDA.Guild.icon_url/2`, `EDA.Emoji.image_url/2`).
  #
  # Discord's rules, from its image formatting reference: the extension picks the format; a hash
  # starting with `a_` is animated and exists as GIF, or as animated WebP with `?animated=true`;
  # `?size=` takes a power of two from 16 to 4096.

  @base "https://cdn.discordapp.com"
  @formats %{png: "png", jpg: "jpg", jpeg: "jpg", webp: "webp", gif: "gif"}
  @sizes for n <- 4..12, do: Integer.pow(2, n)

  @doc false
  def base, do: @base

  @doc false
  # `path` is everything after the base URL, without the extension. `animated?` says whether the
  # image has an animated version.
  #
  # Options:
  #   * `:format` — `:png`, `:jpg`, `:webp` or `:gif`. Defaults to `:gif` for an animated image
  #     and `:png` otherwise. `:webp` of an animated image stays animated.
  #   * `:size` — a power of two from 16 to 4096
  #   * `:animated` — `false` for the still of an animated image
  @spec url(String.t(), boolean(), keyword()) :: String.t()
  def url(path, animated?, opts \\ []) do
    animated? = animated? and Keyword.get(opts, :animated, true)
    format = format!(Keyword.get(opts, :format, if(animated?, do: :gif, else: :png)), animated?)

    query =
      [
        size: size!(opts[:size]),
        animated: if(animated? and format == "webp", do: "true")
      ]
      |> Enum.reject(fn {_k, v} -> is_nil(v) end)

    "#{@base}/#{path}.#{format}" <> if(query == [], do: "", else: "?" <> URI.encode_query(query))
  end

  @doc false
  def animated_hash?(hash) when is_binary(hash), do: String.starts_with?(hash, "a_")
  def animated_hash?(_hash), do: false

  defp format!(:gif, false),
    do: raise(ArgumentError, "this image is not animated, so it has no GIF version")

  defp format!(format, _animated?) when is_map_key(@formats, format),
    do: Map.fetch!(@formats, format)

  defp format!(other, _animated?) do
    raise ArgumentError,
          "an image format is :png, :jpg, :webp or :gif, got: #{inspect(other)}"
  end

  defp size!(nil), do: nil
  defp size!(size) when size in @sizes, do: size

  defp size!(other) do
    raise ArgumentError,
          "an image size is a power of two from 16 to 4096, got: #{inspect(other)}"
  end
end
