defmodule EDA.Event.MessageReactionRemoveEmoji do
  @moduledoc "Dispatched when all reactions for a given emoji are removed from a message."
  use EDA.Event.Access
  defstruct [:channel_id, :message_id, :guild_id, :emoji]

  @type t :: %__MODULE__{
          channel_id: String.t() | nil,
          message_id: String.t() | nil,
          guild_id: String.t() | nil,
          emoji: EDA.Emoji.t() | nil
        }
  @doc "Converts a raw Discord payload into this event struct."
  @spec from_raw(map()) :: t()
  def from_raw(%__MODULE__{} = parsed), do: parsed

  def from_raw(raw) when is_map(raw) do
    %__MODULE__{
      channel_id: :maps.get("channel_id", raw, nil),
      message_id: :maps.get("message_id", raw, nil),
      guild_id: :maps.get("guild_id", raw, nil),
      emoji: parse_emoji(:maps.get("emoji", raw, nil))
    }
  end

  defp parse_emoji(nil), do: nil
  defp parse_emoji(raw) when is_map(raw), do: EDA.Emoji.from_raw(raw)
end
