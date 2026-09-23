defmodule EDA.Poll.Answer do
  @moduledoc """
  Represents a single answer option in a Discord poll.

  This struct flattens `text` and `emoji` directly for a simpler API
  instead of wrapping them in a separate media object.

  ## Example

      %EDA.Poll.Answer{
        answer_id: 1,
        text: "Option A",
        emoji: %EDA.Emoji{id: nil, name: "👍"}
      }
  """

  use EDA.Event.Access

  defstruct [:answer_id, :text, :emoji]

  @type t :: %__MODULE__{
          answer_id: integer() | nil,
          text: String.t(),
          emoji: EDA.Emoji.t() | nil
        }

  @doc """
  Parses a poll answer from a raw Discord API map.

  Extracts `text` and `emoji` from the nested `"poll_media"` object.

  ## Examples

      iex> EDA.Poll.Answer.from_raw(%{"answer_id" => 1, "poll_media" => %{"text" => "Yes", "emoji" => %{"name" => "👍"}}})
      %EDA.Poll.Answer{answer_id: 1, text: "Yes", emoji: %EDA.Emoji{name: "👍"}}

      iex> EDA.Poll.Answer.from_raw(%{"answer_id" => 2, "poll_media" => %{"text" => "No"}})
      %EDA.Poll.Answer{answer_id: 2, text: "No", emoji: nil}
  """
  @spec from_raw(map()) :: t()
  def from_raw(%__MODULE__{} = parsed), do: parsed

  def from_raw(raw) when is_map(raw) do
    media = :maps.get("poll_media", raw, nil) || %{}

    %__MODULE__{
      answer_id: :maps.get("answer_id", raw, nil),
      text: media["text"],
      emoji: parse_emoji(media["emoji"])
    }
  end

  @doc """
  Serializes an answer to the Discord API format.

  Wraps `text` and `emoji` inside a `"poll_media"` object as Discord expects.

  ## Examples

      iex> EDA.Poll.Answer.to_raw(%EDA.Poll.Answer{text: "Yes", emoji: %EDA.Emoji{name: "👍"}})
      %{"poll_media" => %{"text" => "Yes", "emoji" => %{"name" => "👍"}}}

      iex> EDA.Poll.Answer.to_raw(%EDA.Poll.Answer{text: "No"})
      %{"poll_media" => %{"text" => "No"}}
  """
  @spec to_raw(t()) :: map()
  def to_raw(%__MODULE__{} = answer) do
    media = %{"text" => answer.text}

    media =
      case answer.emoji do
        nil -> media
        %EDA.Emoji{id: nil, name: name} -> Map.put(media, "emoji", %{"name" => name})
        %EDA.Emoji{id: id, name: name} -> Map.put(media, "emoji", %{"id" => id, "name" => name})
      end

    %{"poll_media" => media}
  end

  defp parse_emoji(nil), do: nil
  defp parse_emoji(raw) when is_map(raw), do: EDA.Emoji.from_raw(raw)
end
