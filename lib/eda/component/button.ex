defmodule EDA.Component.Button do
  @moduledoc """
  A button. `style` is `:primary`, `:secondary`, `:success`, `:danger`, `:link` or `:premium`;
  a link button has a `url` and no `custom_id`, a premium one a `sku_id`.
  """

  use EDA.Event.Access

  alias EDA.Component

  defstruct [:id, :style, :label, :emoji, :custom_id, :sku_id, :url, :disabled, type: :button]

  @type t :: %__MODULE__{
          type: :button,
          id: integer() | nil,
          style: Component.button_style() | integer() | nil,
          label: String.t() | nil,
          emoji: EDA.Emoji.t() | nil,
          custom_id: String.t() | nil,
          sku_id: String.t() | nil,
          url: String.t() | nil,
          disabled: boolean()
        }

  @doc false
  @spec from_raw(map()) :: t()
  def from_raw(raw) when is_map(raw) do
    %__MODULE__{
      id: raw["id"],
      style: Component.button_style(raw["style"]),
      label: raw["label"],
      emoji: Component.parse_emoji(raw["emoji"]),
      custom_id: raw["custom_id"],
      sku_id: raw["sku_id"],
      url: raw["url"],
      disabled: raw["disabled"] == true
    }
  end
end

defimpl Jason.Encoder, for: EDA.Component.Button do
  def encode(component, opts), do: component |> EDA.Component.to_raw() |> Jason.Encode.map(opts)
end
