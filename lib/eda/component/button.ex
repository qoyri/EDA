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
  def from_raw(%__MODULE__{} = parsed), do: parsed

  def from_raw(raw) when is_map(raw) do
    %__MODULE__{
      id: :maps.get("id", raw, nil),
      style: Component.button_style(:maps.get("style", raw, nil)),
      label: :maps.get("label", raw, nil),
      emoji: Component.parse_emoji(:maps.get("emoji", raw, nil)),
      custom_id: :maps.get("custom_id", raw, nil),
      sku_id: :maps.get("sku_id", raw, nil),
      url: :maps.get("url", raw, nil),
      disabled: :maps.get("disabled", raw, nil) == true
    }
  end
end

defimpl Jason.Encoder, for: EDA.Component.Button do
  def encode(component, opts), do: component |> EDA.Component.to_raw() |> Jason.Encode.map(opts)
end
