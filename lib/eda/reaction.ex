defmodule EDA.Reaction do
  @moduledoc "Represents a Discord message reaction."
  use EDA.Event.Access

  defstruct [:count, :me, :emoji, :count_details, :me_burst, :burst_colors]

  @type t :: %__MODULE__{
          count: integer() | nil,
          me: boolean() | nil,
          emoji: EDA.Emoji.t() | nil,
          count_details: %{burst: non_neg_integer(), normal: non_neg_integer()} | nil,
          me_burst: boolean() | nil,
          burst_colors: [String.t()] | nil
        }

  @spec from_raw(map()) :: t()
  def from_raw(raw) when is_map(raw) do
    %__MODULE__{
      count: raw["count"],
      me: raw["me"],
      emoji: parse_emoji(raw["emoji"]),
      count_details: parse_count_details(raw["count_details"]),
      me_burst: raw["me_burst"],
      burst_colors: raw["burst_colors"]
    }
  end

  defp parse_emoji(nil), do: nil
  defp parse_emoji(raw) when is_map(raw), do: EDA.Emoji.from_raw(raw)

  # Discord's breakdown of the count: super reactions (burst) and normal ones.
  defp parse_count_details(%{"burst" => burst, "normal" => normal}),
    do: %{burst: burst, normal: normal}

  defp parse_count_details(_), do: nil
end
