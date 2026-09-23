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
  def from_raw(raw) when is_map(raw) do
    %__MODULE__{
      channel_id: raw["channel_id"],
      message_id: raw["message_id"],
      guild_id: raw["guild_id"],
      emoji: parse_emoji(raw["emoji"])
    }
  end

  defp parse_emoji(nil), do: nil
  defp parse_emoji(raw) when is_map(raw), do: EDA.Emoji.from_raw(raw)
end
