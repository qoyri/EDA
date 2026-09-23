defmodule EDA.Component.Media do
  @moduledoc """
  The image, video or file a thumbnail, a media gallery item or a file component shows.

  A bot sends only `url`, a link or `attachment://<filename>`. Discord resolves it into the rest:
  its cached copy in `proxy_url`, the size, the `content_type`, the `attachment_id` for an
  uploaded file, and a `placeholder` (a small thumbhash, base64) to show while it loads.
  """

  use EDA.Event.Access

  defstruct [
    :url,
    :proxy_url,
    :height,
    :width,
    :content_type,
    :attachment_id,
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
          attachment_id: String.t() | nil,
          placeholder: String.t() | nil,
          placeholder_version: non_neg_integer() | nil,
          flags: non_neg_integer() | nil
        }

  @doc false
  @spec from_raw(map() | nil) :: t() | nil
  def from_raw(nil), do: nil

  def from_raw(%__MODULE__{} = parsed), do: parsed

  def from_raw(raw) when is_map(raw) do
    %__MODULE__{
      url: :maps.get("url", raw, nil),
      proxy_url: :maps.get("proxy_url", raw, nil),
      height: :maps.get("height", raw, nil),
      width: :maps.get("width", raw, nil),
      content_type: :maps.get("content_type", raw, nil),
      attachment_id: :maps.get("attachment_id", raw, nil),
      placeholder: :maps.get("placeholder", raw, nil),
      placeholder_version: :maps.get("placeholder_version", raw, nil),
      flags: :maps.get("flags", raw, nil)
    }
  end
end

defimpl Jason.Encoder, for: EDA.Component.Media do
  def encode(%{url: url}, opts), do: Jason.Encode.map(%{url: url}, opts)
end
