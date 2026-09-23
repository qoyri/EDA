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
  def from_raw(%__MODULE__{} = parsed), do: parsed

  def from_raw(raw) when is_map(raw) do
    %__MODULE__{
      label: :maps.get("label", raw, nil),
      value: :maps.get("value", raw, nil),
      description: :maps.get("description", raw, nil),
      emoji: Component.parse_emoji(:maps.get("emoji", raw, nil)),
      default: :maps.get("default", raw, nil) == true
    }
  end
end

defimpl Jason.Encoder, for: EDA.Component.SelectOption do
  def encode(component, opts), do: component |> EDA.Component.to_raw() |> Jason.Encode.map(opts)
end
