defmodule EDA.Component.MediaGallery.Item do
  @moduledoc """
  One image or video of a media gallery, with its alt text in `description`.
  """

  use EDA.Event.Access

  defstruct [:media, :description, spoiler: false]

  @type t :: %__MODULE__{
          media: EDA.Component.Media.t() | nil,
          description: String.t() | nil,
          spoiler: boolean()
        }

  @doc false
  @spec from_raw(map()) :: t()
  def from_raw(%__MODULE__{} = parsed), do: parsed

  def from_raw(raw) when is_map(raw) do
    %__MODULE__{
      media: EDA.Component.Media.from_raw(:maps.get("media", raw, nil)),
      description: :maps.get("description", raw, nil),
      spoiler: :maps.get("spoiler", raw, nil) == true
    }
  end
end

defimpl Jason.Encoder, for: EDA.Component.MediaGallery.Item do
  def encode(item, opts), do: item |> EDA.Component.to_raw() |> Jason.Encode.map(opts)
end
