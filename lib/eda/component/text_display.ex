defmodule EDA.Component.TextDisplay do
  @moduledoc """
  Markdown text.
  """

  use EDA.Event.Access

  defstruct [:id, :content, type: :text_display]

  @type t :: %__MODULE__{
          type: :text_display,
          id: integer() | nil,
          content: String.t() | nil
        }

  @doc false
  @spec from_raw(map()) :: t()
  def from_raw(raw) when is_map(raw) do
    %__MODULE__{
      id: raw["id"],
      content: raw["content"]
    }
  end
end

defimpl Jason.Encoder, for: EDA.Component.TextDisplay do
  def encode(component, opts), do: component |> EDA.Component.to_raw() |> Jason.Encode.map(opts)
end
