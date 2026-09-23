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
  def from_raw(%__MODULE__{} = parsed), do: parsed

  def from_raw(raw) when is_map(raw) do
    %__MODULE__{
      id: :maps.get("id", raw, nil),
      media: EDA.Component.Media.from_raw(:maps.get("media", raw, nil)),
      description: :maps.get("description", raw, nil),
      spoiler: :maps.get("spoiler", raw, nil) == true
    }
  end
end

defimpl Jason.Encoder, for: EDA.Component.Thumbnail do
  def encode(component, opts), do: component |> EDA.Component.to_raw() |> Jason.Encode.map(opts)
end
