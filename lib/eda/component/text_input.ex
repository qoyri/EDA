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
  def from_raw(%__MODULE__{} = parsed), do: parsed

  def from_raw(raw) when is_map(raw) do
    %__MODULE__{
      id: :maps.get("id", raw, nil),
      custom_id: :maps.get("custom_id", raw, nil),
      style: Component.text_input_style(:maps.get("style", raw, nil)),
      label: :maps.get("label", raw, nil),
      min_length: :maps.get("min_length", raw, nil),
      max_length: :maps.get("max_length", raw, nil),
      required: :maps.get("required", raw, nil),
      value: :maps.get("value", raw, nil),
      placeholder: :maps.get("placeholder", raw, nil)
    }
  end
end

defimpl Jason.Encoder, for: EDA.Component.TextInput do
  def encode(component, opts), do: component |> EDA.Component.to_raw() |> Jason.Encode.map(opts)
end
