defmodule EDA.Component.Separator do
  @moduledoc """
  Space between components, with a line if `divider` is true. `spacing` is `:small` or `:large`.
  """

  use EDA.Event.Access

  alias EDA.Component

  defstruct [:id, :divider, :spacing, type: :separator]

  @type t :: %__MODULE__{
          type: :separator,
          id: integer() | nil,
          divider: boolean() | nil,
          spacing: :small | :large | integer() | nil
        }

  @doc false
  @spec from_raw(map()) :: t()
  def from_raw(raw) when is_map(raw) do
    %__MODULE__{
      id: raw["id"],
      divider: raw["divider"],
      spacing: Component.spacing(raw["spacing"])
    }
  end
end

defimpl Jason.Encoder, for: EDA.Component.Separator do
  def encode(component, opts), do: component |> EDA.Component.to_raw() |> Jason.Encode.map(opts)
end
