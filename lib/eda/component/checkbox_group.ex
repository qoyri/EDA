defmodule EDA.Component.CheckboxGroup do
  @moduledoc """
  Several choices among `options` in a modal; in a submission, `values` are those checked.
  """

  use EDA.Event.Access

  alias EDA.Component

  defstruct [
    :id,
    :custom_id,
    :options,
    :min_values,
    :max_values,
    :required,
    :values,
    type: :checkbox_group
  ]

  @type t :: %__MODULE__{
          type: :checkbox_group,
          id: integer() | nil,
          custom_id: String.t() | nil,
          options: [EDA.Component.SelectOption.t()] | nil,
          min_values: non_neg_integer() | nil,
          max_values: non_neg_integer() | nil,
          required: boolean() | nil,
          values: [String.t()] | nil
        }

  @doc false
  @spec from_raw(map()) :: t()
  def from_raw(raw) when is_map(raw) do
    %__MODULE__{
      id: raw["id"],
      custom_id: raw["custom_id"],
      options: Component.parse_options(raw["options"]),
      min_values: raw["min_values"],
      max_values: raw["max_values"],
      required: raw["required"],
      values: raw["values"]
    }
  end
end

defimpl Jason.Encoder, for: EDA.Component.CheckboxGroup do
  def encode(component, opts), do: component |> EDA.Component.to_raw() |> Jason.Encode.map(opts)
end
