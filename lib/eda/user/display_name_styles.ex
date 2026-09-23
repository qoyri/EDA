defmodule EDA.User.DisplayNameStyles do
  @moduledoc """
  How a user's name is drawn: its font, its effect and its colours.

  Discord sends this object on users and on guild members (a member's own style for that guild)
  but **does not document it**. Seen on 77 of 622 users of a real bot on 2026-09-23, for example:

      %{"font_id" => 12, "effect_id" => 4, "colors" => ["16752459"]}

  `colors` arrived as integers for some users and as strings for others; they are integers here
  (`0xRRGGBB`), whichever Discord sent. What each `font_id` and `effect_id` means is not
  published.
  """

  use EDA.Event.Access

  defstruct [:font_id, :effect_id, :colors]

  @type t :: %__MODULE__{
          font_id: integer() | nil,
          effect_id: integer() | nil,
          colors: [non_neg_integer()] | nil
        }

  @doc """
  Parses the raw object. Returns `nil` when absent or null.

      iex> EDA.User.DisplayNameStyles.from_raw(%{"font_id" => 3, "colors" => ["16752459", 0]})
      %EDA.User.DisplayNameStyles{font_id: 3, effect_id: nil, colors: [16752459, 0]}
  """
  @spec from_raw(map() | nil) :: t() | nil
  def from_raw(nil), do: nil

  def from_raw(raw) when is_map(raw) do
    %__MODULE__{
      font_id: raw["font_id"],
      effect_id: raw["effect_id"],
      colors: parse_colors(raw["colors"])
    }
  end

  def from_raw(_), do: nil

  defp parse_colors(nil), do: nil
  defp parse_colors(list) when is_list(list), do: Enum.flat_map(list, &color/1)

  defp color(value) when is_integer(value), do: [value]

  defp color(value) when is_binary(value) do
    case Integer.parse(value) do
      {int, ""} -> [int]
      _ -> []
    end
  end

  defp color(_), do: []
end
