defmodule EDA.Component.ActionRow do
  @moduledoc """
  A row of up to five buttons, or one select menu.
  """

  use EDA.Event.Access

  alias EDA.Component

  defstruct [:id, :components, type: :action_row]

  @type t :: %__MODULE__{
          type: :action_row,
          id: integer() | nil,
          components: [EDA.Component.t()]
        }

  @doc false
  @spec from_raw(map()) :: t()
  def from_raw(raw) when is_map(raw) do
    %__MODULE__{
      id: raw["id"],
      components: Component.parse_list(raw["components"])
    }
  end
end

defimpl Jason.Encoder, for: EDA.Component.ActionRow do
  def encode(component, opts), do: component |> EDA.Component.to_raw() |> Jason.Encode.map(opts)
end
