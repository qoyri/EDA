defmodule EDA.Component.Thumbnail do
  @moduledoc """
  A small image, the accessory of a section.
  """

  use EDA.Event.Access

  defstruct [:id, :media, :description, :spoiler, type: :thumbnail]

  @type t :: %__MODULE__{
          type: :thumbnail,
          id: integer() | nil,
          media: EDA.Component.Media.t() | nil,
          description: String.t() | nil,
          spoiler: boolean()
        }

  @doc false
  @spec from_raw(map()) :: t()
  def from_raw(raw) when is_map(raw) do
    %__MODULE__{
      id: raw["id"],
      media: EDA.Component.Media.from_raw(raw["media"]),
      description: raw["description"],
      spoiler: raw["spoiler"] == true
    }
  end
end

defimpl Jason.Encoder, for: EDA.Component.Thumbnail do
  def encode(component, opts), do: component |> EDA.Component.to_raw() |> Jason.Encode.map(opts)
end
