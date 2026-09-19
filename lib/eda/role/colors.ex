defmodule EDA.Role.Colors do
  @moduledoc """
  A role's colours, including gradients.

  Supersedes the role's single `color` field, which Discord deprecated. A role
  always carries all three keys; `secondary_color` and `tertiary_color` are `nil`
  for a plain solid colour.

  Observed on a real guild (2026-09-19): `primary_color` mirrors the legacy
  `color` field, and the `ENHANCED_ROLE_COLORS` guild feature was **absent** even
  though gradients were in use — so do not gate on that feature to decide whether
  to read this.

  ## Example

      %EDA.Role.Colors{
        primary_color: 10_382_335,
        secondary_color: 12_427_263,
        tertiary_color: nil
      }
  """

  use EDA.Event.Access

  defstruct [:primary_color, :secondary_color, :tertiary_color]

  @type t :: %__MODULE__{
          primary_color: integer() | nil,
          secondary_color: integer() | nil,
          tertiary_color: integer() | nil
        }

  @doc "Parses the raw `colors` object. Returns `nil` when absent."
  @spec from_raw(map() | nil) :: t() | nil
  def from_raw(nil), do: nil

  def from_raw(raw) when is_map(raw) do
    %__MODULE__{
      primary_color: raw["primary_color"],
      secondary_color: raw["secondary_color"],
      tertiary_color: raw["tertiary_color"]
    }
  end

  def from_raw(_), do: nil

  @doc """
  Returns `true` when the role uses a gradient rather than a solid colour.

  ## Examples

      iex> EDA.Role.Colors.gradient?(%EDA.Role.Colors{primary_color: 1, secondary_color: 2})
      true

      iex> EDA.Role.Colors.gradient?(%EDA.Role.Colors{primary_color: 1})
      false

      iex> EDA.Role.Colors.gradient?(nil)
      false
  """
  @spec gradient?(t() | nil) :: boolean()
  def gradient?(%__MODULE__{secondary_color: nil, tertiary_color: nil}), do: false
  def gradient?(%__MODULE__{}), do: true
  def gradient?(nil), do: false
end
