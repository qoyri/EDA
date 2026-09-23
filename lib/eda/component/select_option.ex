defmodule EDA.Component.SelectOption do
  @moduledoc """
  One choice of a string select menu.
  """

  use EDA.Event.Access

  alias EDA.Component

  defstruct [:label, :value, :description, :emoji, :default]

  @type t :: %__MODULE__{
          label: String.t() | nil,
          value: String.t() | nil,
          description: String.t() | nil,
          emoji: EDA.Emoji.t() | nil,
          default: boolean()
        }

  @doc false
  @spec from_raw(map()) :: t()
  def from_raw(raw) when is_map(raw) do
    %__MODULE__{
      label: raw["label"],
      value: raw["value"],
      description: raw["description"],
      emoji: Component.parse_emoji(raw["emoji"]),
      default: raw["default"] == true
    }
  end
end

defimpl Jason.Encoder, for: EDA.Component.SelectOption do
  def encode(component, opts), do: component |> EDA.Component.to_raw() |> Jason.Encode.map(opts)
end
