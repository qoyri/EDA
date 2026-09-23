defmodule EDA.Event.TypingStart do
  @moduledoc "Dispatched when a user starts typing in a channel."
  use EDA.Event.Access
  defstruct [:channel_id, :guild_id, :user_id, :timestamp, :member]

  @type t :: %__MODULE__{
          channel_id: String.t() | nil,
          guild_id: String.t() | nil,
          user_id: String.t() | nil,
          timestamp: DateTime.t() | nil,
          member: EDA.Member.t() | nil
        }
  @doc "Converts a raw Discord payload into this event struct."
  @spec from_raw(map()) :: t()
  def from_raw(%__MODULE__{} = parsed), do: parsed

  def from_raw(raw) when is_map(raw) do
    %__MODULE__{
      channel_id: :maps.get("channel_id", raw, nil),
      guild_id: :maps.get("guild_id", raw, nil),
      user_id: :maps.get("user_id", raw, nil),
      timestamp: EDA.Timestamp.from_unix(:maps.get("timestamp", raw, nil)),
      member: parse_member(:maps.get("member", raw, nil))
    }
  end

  defp parse_member(nil), do: nil
  defp parse_member(raw) when is_map(raw), do: EDA.Member.from_raw(raw)
end
