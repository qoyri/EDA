defmodule EDA.Embed.Footer do
  @moduledoc """
  An embed's footer: its text and an optional icon.

  `proxy_icon_url` is set by Discord on an embed it has received, never when sending.
  """

  use EDA.Event.Access

  defstruct [:text, :icon_url, :proxy_icon_url]

  @type t :: %__MODULE__{
          text: String.t() | nil,
          icon_url: String.t() | nil,
          proxy_icon_url: String.t() | nil
        }

  @doc false
  @spec from_raw(map() | nil) :: t() | nil
  def from_raw(nil), do: nil

  def from_raw(raw) when is_map(raw) do
    %__MODULE__{
      text: raw["text"],
      icon_url: raw["icon_url"],
      proxy_icon_url: raw["proxy_icon_url"]
    }
  end
end
