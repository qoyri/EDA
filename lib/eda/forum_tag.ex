defmodule EDA.ForumTag do
  @moduledoc """
  Represents a tag available in a Discord Forum or Media channel.

  Forum tags can be applied to threads (posts) within a forum channel to help
  organize discussions. Each tag has a name, an optional emoji, and a moderated
  flag that restricts who can apply it.

  ## Existing vs new tags

  Tags returned from the Discord API have an `id` (snowflake string).
  Tags you create programmatically with `new/2` have `id: nil` — Discord
  assigns the ID when the channel is updated with the new tag list.

  ## Examples

      # Parse a tag from Discord API data
      tag = EDA.ForumTag.from_raw(%{
        "id" => "123456",
        "name" => "Resolved",
        "moderated" => true,
        "emoji_id" => nil,
        "emoji_name" => "✅"
      })

      # Create a new tag programmatically
      tag = EDA.ForumTag.new("Bug Report", moderated: true, emoji: "🐛")

      # Serialize for API (e.g. updating available_tags on a channel)
      EDA.ForumTag.to_raw(tag)
  """

  use EDA.Event.Access

  defstruct [:id, :name, :moderated, :emoji_id, :emoji_name]

  @type t :: %__MODULE__{
          id: String.t() | nil,
          name: String.t() | nil,
          moderated: boolean() | nil,
          emoji_id: String.t() | nil,
          emoji_name: String.t() | nil
        }

  @doc """
  Parses a forum tag from a raw Discord API map.

  ## Examples

      iex> EDA.ForumTag.from_raw(%{"id" => "1", "name" => "Bug", "moderated" => false, "emoji_id" => nil, "emoji_name" => "🐛"})
      %EDA.ForumTag{id: "1", name: "Bug", moderated: false, emoji_id: nil, emoji_name: "🐛"}
  """
  @spec from_raw(map()) :: t()
  def from_raw(%__MODULE__{} = parsed), do: parsed

  def from_raw(raw) when is_map(raw) do
    %__MODULE__{
      id: :maps.get("id", raw, nil),
      name: :maps.get("name", raw, nil),
      moderated: :maps.get("moderated", raw, nil) || false,
      emoji_id: :maps.get("emoji_id", raw, nil),
      emoji_name: :maps.get("emoji_name", raw, nil)
    }
  end

  @doc """
  Serializes a forum tag for the Discord API.

  Omits keys with `nil` values so Discord doesn't receive explicit nulls.

  ## Examples

      iex> tag = %EDA.ForumTag{id: "1", name: "Bug", moderated: false, emoji_name: "🐛"}
      iex> EDA.ForumTag.to_raw(tag)
      %{"id" => "1", "name" => "Bug", "moderated" => false, "emoji_name" => "🐛"}
  """
  @spec to_raw(t()) :: map()
  def to_raw(%__MODULE__{} = tag) do
    %{
      "name" => tag.name,
      "moderated" => tag.moderated
    }
    |> maybe_put("id", tag.id)
    |> maybe_put("emoji_id", tag.emoji_id)
    |> maybe_put("emoji_name", tag.emoji_name)
  end

  @doc """
  Creates a new forum tag struct (without an ID).

  ## Options

    * `:moderated` - if `true`, only users with `MANAGE_THREADS` can apply
      this tag. Defaults to `false`.
    * `:emoji` - an `EDA.Emoji` struct or a unicode string (e.g. `"🐛"`).

  ## Examples

      iex> EDA.ForumTag.new("Help")
      %EDA.ForumTag{name: "Help", moderated: false}

      iex> EDA.ForumTag.new("Bug", moderated: true, emoji: "🐛")
      %EDA.ForumTag{name: "Bug", moderated: true, emoji_name: "🐛"}

      iex> EDA.ForumTag.new("Cool", emoji: %EDA.Emoji{id: "99", name: "cool"})
      %EDA.ForumTag{name: "Cool", moderated: false, emoji_id: "99", emoji_name: "cool"}
  """
  @spec new(String.t(), keyword()) :: t()
  def new(name, opts \\ []) when is_binary(name) do
    moderated = Keyword.get(opts, :moderated, false)
    {emoji_id, emoji_name} = resolve_emoji(Keyword.get(opts, :emoji))

    %__MODULE__{
      name: name,
      moderated: moderated,
      emoji_id: emoji_id,
      emoji_name: emoji_name
    }
  end

  defp resolve_emoji(nil), do: {nil, nil}
  defp resolve_emoji(%EDA.Emoji{id: id, name: name}), do: {id, name}
  defp resolve_emoji(str) when is_binary(str), do: {nil, str}

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
