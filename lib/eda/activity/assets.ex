defmodule EDA.Activity.Assets do
  @moduledoc """
  An activity's images and their hover texts. An image is an application asset id, or a
  prefixed reference such as `mp:external/…` (proxied) or `spotify:<id>`; each may link to
  `large_url` or `small_url`, and `invite_cover_image` illustrates an invite to the activity.
  """

  use EDA.Event.Access

  defstruct [
    :large_image,
    :large_text,
    :large_url,
    :small_image,
    :small_text,
    :small_url,
    :invite_cover_image
  ]

  @type t :: %__MODULE__{
          large_image: String.t() | nil,
          large_text: String.t() | nil,
          large_url: String.t() | nil,
          small_image: String.t() | nil,
          small_text: String.t() | nil,
          small_url: String.t() | nil,
          invite_cover_image: String.t() | nil
        }

  @doc false
  @spec from_raw(map() | nil) :: t() | nil
  def from_raw(nil), do: nil

  def from_raw(raw) when is_map(raw) do
    %__MODULE__{
      large_image: raw["large_image"],
      large_text: raw["large_text"],
      large_url: raw["large_url"],
      small_image: raw["small_image"],
      small_text: raw["small_text"],
      small_url: raw["small_url"],
      invite_cover_image: raw["invite_cover_image"]
    }
  end
end
