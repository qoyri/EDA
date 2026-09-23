defmodule EDA.Component.TextInput do
  @moduledoc """
  A text field in a modal. `style` is `:short` or `:paragraph`; in a submission, `value` is what
  the user typed.
  """

  use EDA.Event.Access

  alias EDA.Component

  defstruct [
    :id,
    :custom_id,
    :style,
    :label,
    :min_length,
    :max_length,
    :required,
    :value,
    :placeholder,
    type: :text_input
  ]

  @type t :: %__MODULE__{
          type: :text_input,
          id: integer() | nil,
          custom_id: String.t() | nil,
          style: :short | :paragraph | integer() | nil,
          label: String.t() | nil,
          min_length: non_neg_integer() | nil,
          max_length: non_neg_integer() | nil,
          required: boolean() | nil,
          value: String.t() | nil,
          placeholder: String.t() | nil
        }

  @doc false
  @spec from_raw(map()) :: t()
  def from_raw(raw) when is_map(raw) do
    %__MODULE__{
      id: raw["id"],
      custom_id: raw["custom_id"],
      style: Component.text_input_style(raw["style"]),
      label: raw["label"],
      min_length: raw["min_length"],
      max_length: raw["max_length"],
      required: raw["required"],
      value: raw["value"],
      placeholder: raw["placeholder"]
    }
  end
end

defimpl Jason.Encoder, for: EDA.Component.TextInput do
  def encode(component, opts), do: component |> EDA.Component.to_raw() |> Jason.Encode.map(opts)
end
