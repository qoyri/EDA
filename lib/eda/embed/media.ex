defmodule EDA.Embed.Media do
  @moduledoc """
  An embed's image, thumbnail or video.

  A bot sends only `url`. On an embed it receives, Discord adds its cached copy in `proxy_url`,
  the size, the `content_type`, and a `placeholder` (a small thumbhash, base64) to show while
  the image loads. `animated?/1` reads `flags`.
  """

  import Bitwise

  use EDA.Event.Access

  defstruct [
    :url,
    :proxy_url,
    :height,
    :width,
    :content_type,
    :placeholder,
    :placeholder_version,
    :flags
  ]

  @type t :: %__MODULE__{
          url: String.t() | nil,
          proxy_url: String.t() | nil,
          height: non_neg_integer() | nil,
          width: non_neg_integer() | nil,
          content_type: String.t() | nil,
          placeholder: String.t() | nil,
          placeholder_version: non_neg_integer() | nil,
          flags: non_neg_integer() | nil
        }

  @is_animated 1 <<< 5

  @doc false
  @spec from_raw(map() | nil) :: t() | nil
  def from_raw(nil), do: nil

  def from_raw(raw) when is_map(raw) do
    %__MODULE__{
      url: raw["url"],
      proxy_url: raw["proxy_url"],
      height: raw["height"],
      width: raw["width"],
      content_type: raw["content_type"],
      placeholder: raw["placeholder"],
      placeholder_version: raw["placeholder_version"],
      flags: raw["flags"]
    }
  end

  @doc """
  Whether the image is animated, as Discord flags it.

      iex> EDA.Embed.Media.animated?(%EDA.Embed.Media{flags: 32})
      true
      iex> EDA.Embed.Media.animated?(%EDA.Embed.Media{url: "https://example.com/a.png"})
      false
  """
  @spec animated?(t()) :: boolean()
  def animated?(%__MODULE__{flags: flags}) when is_integer(flags),
    do: (flags &&& @is_animated) != 0

  def animated?(%__MODULE__{}), do: false
end
