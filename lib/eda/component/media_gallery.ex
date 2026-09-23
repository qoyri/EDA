defmodule EDA.Component.MediaGallery do
  @moduledoc """
  One to ten images or videos, shown as a grid.
  """

  use EDA.Event.Access

  defstruct [:id, :items, type: :media_gallery]

  @type t :: %__MODULE__{
          type: :media_gallery,
          id: integer() | nil,
          items: [EDA.Component.MediaGallery.Item.t()]
        }

  @doc false
  @spec from_raw(map()) :: t()
  def from_raw(%__MODULE__{} = parsed), do: parsed

  def from_raw(raw) when is_map(raw) do
    %__MODULE__{
      id: :maps.get("id", raw, nil),
      items:
        Enum.map(:maps.get("items", raw, nil) || [], &EDA.Component.MediaGallery.Item.from_raw/1)
    }
  end
end

defimpl Jason.Encoder, for: EDA.Component.MediaGallery do
  def encode(component, opts), do: component |> EDA.Component.to_raw() |> Jason.Encode.map(opts)
end
