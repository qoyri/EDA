defmodule EDA.Channel.Forum do
  @moduledoc """
  What only a forum or media channel has, held in `EDA.Channel`'s `forum` field — `nil` on any
  other channel.

  - `available_tags` — the tags a post can be given, as `EDA.ForumTag` structs (at most 20)
  - `default_reaction_emoji` — the emoji shown on each post's reaction button, as
    `%{"emoji_id" => ..., "emoji_name" => ...}`
  - `default_sort_order` and `default_forum_layout` — see the `sort_*` and `layout_*` constants on
    `EDA.Channel`
  """

  use EDA.Event.Access

  defstruct [:available_tags, :default_reaction_emoji, :default_sort_order, :default_forum_layout]

  @type t :: %__MODULE__{
          available_tags: [EDA.ForumTag.t()] | nil,
          default_reaction_emoji: map() | nil,
          default_sort_order: non_neg_integer() | nil,
          default_forum_layout: non_neg_integer() | nil
        }

  @doc false
  def raw_keys,
    do: ~w(available_tags default_reaction_emoji default_sort_order default_forum_layout)

  @doc "Takes the forum fields out of a raw channel object."
  @spec from_raw(map()) :: t()
  def from_raw(raw) when is_map(raw) do
    %__MODULE__{
      available_tags: parse_tags(raw["available_tags"]),
      default_reaction_emoji: raw["default_reaction_emoji"],
      default_sort_order: raw["default_sort_order"],
      default_forum_layout: raw["default_forum_layout"]
    }
  end

  defp parse_tags(nil), do: nil
  defp parse_tags(list) when is_list(list), do: Enum.map(list, &EDA.ForumTag.from_raw/1)
end
