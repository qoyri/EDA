defmodule EDA.Onboarding.Option do
  @moduledoc "An answer to an onboarding prompt. Build one with `EDA.Onboarding.option/2`."

  use EDA.Event.Access

  defstruct [:id, :title, :description, :emoji, channel_ids: [], role_ids: []]

  @type t :: %__MODULE__{
          id: String.t() | nil,
          title: String.t() | nil,
          description: String.t() | nil,
          emoji: EDA.Emoji.t() | nil,
          channel_ids: [String.t()],
          role_ids: [String.t()]
        }

  @doc """
  Converts a raw option into this struct. Discord sends the emoji as an object; an empty one
  (no id, no name) is read as no emoji.
  """
  @spec from_raw(map()) :: t()
  def from_raw(raw) when is_map(raw) do
    %__MODULE__{
      id: raw["id"],
      title: raw["title"],
      description: raw["description"],
      emoji: parse_emoji(raw),
      channel_ids: raw["channel_ids"] || [],
      role_ids: raw["role_ids"] || []
    }
  end

  @doc false
  # Discord only accepts the flat emoji fields in a request; the object is ignored and would
  # clear the emoji.
  def to_payload(%__MODULE__{} = option) do
    %{
      id: option.id,
      title: option.title,
      description: option.description,
      channel_ids: option.channel_ids,
      role_ids: option.role_ids
    }
    |> Map.merge(flat_emoji(option.emoji))
  end

  defp flat_emoji(nil), do: %{}

  defp flat_emoji(%EDA.Emoji{id: id, name: name, animated: animated}) do
    %{emoji_id: id, emoji_name: name, emoji_animated: animated || false}
  end

  defp parse_emoji(%{"emoji" => %{"id" => nil, "name" => nil}}), do: nil
  defp parse_emoji(%{"emoji" => %{} = emoji}), do: EDA.Emoji.from_raw(emoji)

  defp parse_emoji(%{"emoji_name" => name} = raw) when is_binary(name),
    do: %EDA.Emoji{id: raw["emoji_id"], name: name, animated: raw["emoji_animated"] || false}

  defp parse_emoji(_raw), do: nil
end
