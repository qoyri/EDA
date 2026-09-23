defmodule EDA.Component.Container do
  @moduledoc """
  A box around other components, with an optional accent colour on its left edge.
  """

  use EDA.Event.Access

  alias EDA.Component

  defstruct [:id, :components, :accent_color, :spoiler, type: :container]

  @type t :: %__MODULE__{
          type: :container,
          id: integer() | nil,
          components: [EDA.Component.t()],
          accent_color: non_neg_integer() | nil,
          spoiler: boolean()
        }

  @doc false
  @spec from_raw(map()) :: t()
  def from_raw(raw) when is_map(raw) do
    %__MODULE__{
      id: raw["id"],
      components: Component.parse_list(raw["components"]),
      accent_color: raw["accent_color"],
      spoiler: raw["spoiler"] == true
    }
  end
end

defimpl Jason.Encoder, for: EDA.Component.Container do
  def encode(component, opts), do: component |> EDA.Component.to_raw() |> Jason.Encode.map(opts)
end
