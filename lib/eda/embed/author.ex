defmodule EDA.Embed.Author do
  @moduledoc """
  An embed's author line: a name, with an optional link and icon.

  `proxy_icon_url` is set by Discord on an embed it has received, never when sending.
  """

  use EDA.Event.Access

  defstruct [:name, :url, :icon_url, :proxy_icon_url]

  @type t :: %__MODULE__{
          name: String.t() | nil,
          url: String.t() | nil,
          icon_url: String.t() | nil,
          proxy_icon_url: String.t() | nil
        }

  @doc false
  @spec from_raw(map() | nil) :: t() | nil
  def from_raw(nil), do: nil

  def from_raw(%__MODULE__{} = parsed), do: parsed

  def from_raw(raw) when is_map(raw) do
    %__MODULE__{
      name: :maps.get("name", raw, nil),
      url: :maps.get("url", raw, nil),
      icon_url: :maps.get("icon_url", raw, nil),
      proxy_icon_url: :maps.get("proxy_icon_url", raw, nil)
    }
  end
end
