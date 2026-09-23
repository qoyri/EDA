defmodule EDA.Channel.Forum do
  @moduledoc """
  What only a forum or media channel has, held in `EDA.Channel`'s `forum` field — `nil` on any
  other channel.

  - `available_tags` — the tags a post can be given, as `EDA.ForumTag` structs (at most 20)
  - `default_reaction_emoji` — the emoji shown on each post's reaction button, as an
    `EDA.Channel.DefaultReaction`
  - `default_sort_order` — `:latest_activity` or `:creation_date`
  - `default_forum_layout` — `:not_set`, `:list_view` or `:gallery_view`
  """

  use EDA.Event.Access

  @sort_orders %{0 => :latest_activity, 1 => :creation_date}
  @layouts %{0 => :not_set, 1 => :list_view, 2 => :gallery_view}

  defstruct [:available_tags, :default_reaction_emoji, :default_sort_order, :default_forum_layout]

  @type t :: %__MODULE__{
          available_tags: [EDA.ForumTag.t()] | nil,
          default_reaction_emoji: EDA.Channel.DefaultReaction.t() | nil,
          default_sort_order: :latest_activity | :creation_date | integer() | nil,
          default_forum_layout: :not_set | :list_view | :gallery_view | integer() | nil
        }

  @doc false
  def raw_keys,
    do: ~w(available_tags default_reaction_emoji default_sort_order default_forum_layout)

  @doc "Takes the forum fields out of a raw channel object."
  @spec from_raw(map()) :: t()
  def from_raw(%__MODULE__{} = parsed), do: parsed

  def from_raw(raw) when is_map(raw) do
    %__MODULE__{
      available_tags: parse_tags(:maps.get("available_tags", raw, nil)),
      default_reaction_emoji:
        EDA.Channel.DefaultReaction.from_raw(:maps.get("default_reaction_emoji", raw, nil)),
      default_sort_order: EDA.Enum.name(@sort_orders, :maps.get("default_sort_order", raw, nil)),
      default_forum_layout: EDA.Enum.name(@layouts, :maps.get("default_forum_layout", raw, nil))
    }
  end

  defp parse_tags(nil), do: nil
  defp parse_tags(list) when is_list(list), do: Enum.map(list, &EDA.ForumTag.from_raw/1)
end
