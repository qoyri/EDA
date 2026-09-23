defmodule EDA.Component.File do
  @moduledoc """
  An attached file, shown as a download.
  """

  use EDA.Event.Access

  defstruct [:id, :file, :spoiler, :name, :size, type: :file]

  @type t :: %__MODULE__{
          type: :file,
          id: integer() | nil,
          file: EDA.Component.Media.t() | nil,
          spoiler: boolean(),
          name: String.t() | nil,
          size: non_neg_integer() | nil
        }

  @doc false
  @spec from_raw(map()) :: t()
  def from_raw(%__MODULE__{} = parsed), do: parsed

  def from_raw(raw) when is_map(raw) do
    %__MODULE__{
      id: :maps.get("id", raw, nil),
      file: EDA.Component.Media.from_raw(:maps.get("file", raw, nil)),
      spoiler: :maps.get("spoiler", raw, nil) == true,
      name: :maps.get("name", raw, nil),
      size: :maps.get("size", raw, nil)
    }
  end
end

defimpl Jason.Encoder, for: EDA.Component.File do
  def encode(component, opts), do: component |> EDA.Component.to_raw() |> Jason.Encode.map(opts)
end
