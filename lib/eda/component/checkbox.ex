defmodule EDA.Component.Checkbox do
  @moduledoc """
  A single checkbox in a modal; in a submission, `value` says whether it was checked.
  """

  use EDA.Event.Access

  defstruct [:id, :custom_id, :default, :value, type: :checkbox]

  @type t :: %__MODULE__{
          type: :checkbox,
          id: integer() | nil,
          custom_id: String.t() | nil,
          default: boolean() | nil,
          value: boolean() | nil
        }

  @doc false
  @spec from_raw(map()) :: t()
  def from_raw(raw) when is_map(raw) do
    %__MODULE__{
      id: raw["id"],
      custom_id: raw["custom_id"],
      default: raw["default"],
      value: raw["value"]
    }
  end
end

defimpl Jason.Encoder, for: EDA.Component.Checkbox do
  def encode(component, opts), do: component |> EDA.Component.to_raw() |> Jason.Encode.map(opts)
end
