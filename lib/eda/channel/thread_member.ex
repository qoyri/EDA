defmodule EDA.Channel.ThreadMember do
  @moduledoc """
  A user's membership of a thread.

  On a thread the bot receives, `EDA.Channel.Thread` holds the bot's own membership, which says
  whether it has joined. `THREAD_MEMBERS_UPDATE` carries other users' memberships, with the guild
  member in `member` when the guild member intent is on.

  `id` (the thread) and `user_id` are left out by Discord in some payloads, such as a thread in
  `GUILD_CREATE`.
  """

  use EDA.Event.Access

  defstruct [:id, :guild_id, :user_id, :join_timestamp, :flags, :member]

  @type t :: %__MODULE__{
          id: String.t() | nil,
          guild_id: String.t() | nil,
          user_id: String.t() | nil,
          join_timestamp: DateTime.t() | nil,
          flags: non_neg_integer() | nil,
          member: EDA.Member.t() | nil
        }

  @doc "Parses a raw thread member object. Returns `nil` when absent."
  @spec from_raw(map() | nil) :: t() | nil
  def from_raw(nil), do: nil

  def from_raw(%__MODULE__{} = parsed), do: parsed

  def from_raw(raw) when is_map(raw) do
    %__MODULE__{
      id: :maps.get("id", raw, nil),
      user_id: :maps.get("user_id", raw, nil),
      join_timestamp: EDA.Timestamp.parse(:maps.get("join_timestamp", raw, nil)),
      flags: :maps.get("flags", raw, nil),
      member: parse_member(:maps.get("member", raw, nil))
    }
  end

  defp parse_member(nil), do: nil
  defp parse_member(raw) when is_map(raw), do: EDA.Member.from_raw(raw)
end
