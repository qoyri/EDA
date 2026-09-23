defmodule EDA.Component.RadioGroup do
  @moduledoc """
  A single choice among `options` in a modal; in a submission, `value` is the one chosen.
  """

  use EDA.Event.Access

  alias EDA.Component

  defstruct [:id, :custom_id, :options, :required, :value, type: :radio_group]

  @type t :: %__MODULE__{
          type: :radio_group,
          id: integer() | nil,
          custom_id: String.t() | nil,
          options: [EDA.Component.SelectOption.t()] | nil,
          required: boolean() | nil,
          value: String.t() | nil
        }

  @doc false
  @spec from_raw(map()) :: t()
  def from_raw(raw) when is_map(raw) do
    %__MODULE__{
      id: raw["id"],
      custom_id: raw["custom_id"],
      options: Component.parse_options(raw["options"]),
      required: raw["required"],
      value: raw["value"]
    }
  end
end

defimpl Jason.Encoder, for: EDA.Component.RadioGroup do
  def encode(component, opts), do: component |> EDA.Component.to_raw() |> Jason.Encode.map(opts)
end
