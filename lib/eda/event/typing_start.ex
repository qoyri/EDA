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
  def from_raw(raw) when is_map(raw) do
    %__MODULE__{
      channel_id: raw["channel_id"],
      guild_id: raw["guild_id"],
      user_id: raw["user_id"],
      timestamp: EDA.Timestamp.from_unix(raw["timestamp"]),
      member: parse_member(raw["member"])
    }
  end

  defp parse_member(nil), do: nil
  defp parse_member(raw) when is_map(raw), do: EDA.Member.from_raw(raw)
end
