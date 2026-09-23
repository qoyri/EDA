defmodule EDA.Event.MessageReactionAdd do
  @moduledoc "Dispatched when a user adds a reaction to a message."
  use EDA.Event.Access
  defstruct [:user_id, :channel_id, :message_id, :guild_id, :member, :emoji]

  @type t :: %__MODULE__{
          user_id: String.t() | nil,
          channel_id: String.t() | nil,
          message_id: String.t() | nil,
          guild_id: String.t() | nil,
          member: EDA.Member.t() | nil,
          emoji: EDA.Emoji.t() | nil
        }
  @doc "Converts a raw Discord payload into this event struct."
  @spec from_raw(map()) :: t()
  def from_raw(%__MODULE__{} = parsed), do: parsed

  def from_raw(raw) when is_map(raw) do
    %__MODULE__{
      user_id: :maps.get("user_id", raw, nil),
      channel_id: :maps.get("channel_id", raw, nil),
      message_id: :maps.get("message_id", raw, nil),
      guild_id: :maps.get("guild_id", raw, nil),
      member: parse_member(:maps.get("member", raw, nil)),
      emoji: parse_emoji(:maps.get("emoji", raw, nil))
    }
  end

  defp parse_member(nil), do: nil
  defp parse_member(raw) when is_map(raw), do: EDA.Member.from_raw(raw)

  defp parse_emoji(nil), do: nil
  defp parse_emoji(raw) when is_map(raw), do: EDA.Emoji.from_raw(raw)
end
