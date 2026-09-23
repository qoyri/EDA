defmodule EDA.Component.Section do
  @moduledoc """
  Up to three text displays with an `accessory` beside them: a thumbnail or a button.
  """

  use EDA.Event.Access

  alias EDA.Component

  defstruct [:id, :components, :accessory, type: :section]

  @type t :: %__MODULE__{
          type: :section,
          id: integer() | nil,
          components: [EDA.Component.t()],
          accessory: EDA.Component.t() | nil
        }

  @doc false
  @spec from_raw(map()) :: t()
  def from_raw(raw) when is_map(raw) do
    %__MODULE__{
      id: raw["id"],
      components: Component.parse_list(raw["components"]),
      accessory: Component.parse(raw["accessory"])
    }
  end
end

defimpl Jason.Encoder, for: EDA.Component.Section do
  def encode(component, opts), do: component |> EDA.Component.to_raw() |> Jason.Encode.map(opts)
end
