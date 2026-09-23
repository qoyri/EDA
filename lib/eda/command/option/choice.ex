defmodule EDA.Command.Option.Choice do
  @moduledoc """
  One of the fixed values a string, integer or number option offers, with the `name` shown to
  the user, its translations, and the `value` the bot receives.
  """

  use EDA.Event.Access

  defstruct [:name, :value, :name_localizations]

  @type t :: %__MODULE__{
          name: String.t() | nil,
          value: String.t() | integer() | float() | nil,
          name_localizations: %{String.t() => String.t()} | nil
        }

  @doc false
  @spec from_raw(map()) :: t()
  def from_raw(raw) when is_map(raw) do
    %__MODULE__{
      name: raw["name"],
      value: raw["value"],
      name_localizations: raw["name_localizations"]
    }
  end

  @doc false
  @spec to_map(t()) :: map()
  def to_map(%__MODULE__{name_localizations: nil} = choice),
    do: %{name: choice.name, value: choice.value}

  def to_map(%__MODULE__{} = choice),
    do: %{name: choice.name, value: choice.value, name_localizations: choice.name_localizations}
end

defimpl Jason.Encoder, for: EDA.Command.Option.Choice do
  def encode(choice, opts),
    do: choice |> EDA.Command.Option.Choice.to_map() |> Jason.Encode.map(opts)
end
