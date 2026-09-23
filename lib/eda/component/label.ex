defmodule EDA.Component.Label do
  @moduledoc """
  A modal field's title and description, around the input it names, in `component`.
  """

  use EDA.Event.Access

  alias EDA.Component

  defstruct [:id, :label, :description, :component, type: :label]

  @type t :: %__MODULE__{
          type: :label,
          id: integer() | nil,
          label: String.t() | nil,
          description: String.t() | nil,
          component: EDA.Component.t() | nil
        }

  @doc false
  @spec from_raw(map()) :: t()
  def from_raw(%__MODULE__{} = parsed), do: parsed

  def from_raw(raw) when is_map(raw) do
    %__MODULE__{
      id: :maps.get("id", raw, nil),
      label: :maps.get("label", raw, nil),
      description: :maps.get("description", raw, nil),
      component: Component.parse(:maps.get("component", raw, nil))
    }
  end
end

defimpl Jason.Encoder, for: EDA.Component.Label do
  def encode(component, opts), do: component |> EDA.Component.to_raw() |> Jason.Encode.map(opts)
end
