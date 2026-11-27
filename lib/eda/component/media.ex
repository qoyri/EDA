defmodule EDA.Component.Media do
  @moduledoc """
  The image, video or file a thumbnail, a media gallery item or a file component shows.

  A bot sends only `url`, a link or `attachment://<filename>`. Discord resolves it into the rest:
  its cached copy in `proxy_url`, the size, the `content_type`, the `attachment_id` for an
  uploaded file, and a `placeholder` (a small thumbhash, base64) to show while it loads.

  `content_scan_flags` is what Discord's content scanning found, from the media's
  `content_scan_metadata`: `nil` until the media has been scanned, which can be after the
  message is sent — the result then arrives in a `MESSAGE_UPDATE`. `content_flags/1` and
  `flagged?/1` read it.
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
    :flags,
    :content_scan_flags
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
          flags: non_neg_integer() | nil,
          content_scan_flags: non_neg_integer() | nil
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
      flags: :maps.get("flags", raw, nil),
      content_scan_flags: scan_flags(:maps.get("content_scan_metadata", raw, nil))
    }
  end

  defp scan_flags(%{"flags" => flags}), do: flags
  defp scan_flags(_), do: nil

  @doc """
  What Discord's content scanning flagged this media as: any of `:explicit`, `:gore` and
  `:self_harm`, or `[]` — also for media not scanned yet.

      iex> EDA.Component.Media.content_flags(%EDA.Component.Media{content_scan_flags: 0b101})
      [:explicit, :self_harm]

      iex> EDA.Component.Media.content_flags(%EDA.Component.Media{url: "https://example.com/a.png"})
      []
  """
  @spec content_flags(t()) :: [:explicit | :gore | :self_harm]
  def content_flags(%__MODULE__{content_scan_flags: flags}), do: EDA.ContentScan.metadata(flags)

  @doc """
  Whether Discord's content scanning flagged this media as explicit, gore or self-harm.

      iex> EDA.Component.Media.flagged?(%EDA.Component.Media{content_scan_flags: 2})
      true

      iex> EDA.Component.Media.flagged?(%EDA.Component.Media{content_scan_flags: 0})
      false
  """
  @spec flagged?(t()) :: boolean()
  def flagged?(%__MODULE__{} = media), do: content_flags(media) != []
end

defimpl Jason.Encoder, for: EDA.Component.Media do
  def encode(%{url: url}, opts), do: Jason.Encode.map(%{url: url}, opts)
end
