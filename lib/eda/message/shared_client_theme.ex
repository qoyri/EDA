defmodule EDA.Message.SharedClientTheme do
  @moduledoc """
  A client theme shared in a message: its gradient `colors` as hex strings, the
  `gradient_angle` in degrees, how much of them is mixed into the base theme (`base_mix`, 0 to
  100), and that base theme, as Discord's integer.
  """

  use EDA.Event.Access

  defstruct [:colors, :gradient_angle, :base_mix, :base_theme]

  @type t :: %__MODULE__{
          colors: [String.t()] | nil,
          gradient_angle: integer() | nil,
          base_mix: integer() | nil,
          base_theme: integer() | nil
        }

  @doc false
  @spec from_raw(map() | nil) :: t() | nil
  def from_raw(nil), do: nil

  def from_raw(raw) when is_map(raw) do
    %__MODULE__{
      colors: raw["colors"],
      gradient_angle: raw["gradient_angle"],
      base_mix: raw["base_mix"],
      base_theme: raw["base_theme"]
    }
  end
end
