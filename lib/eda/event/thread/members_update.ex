defmodule EDA.Event.ThreadMembersUpdate do
  @moduledoc """
  Sent when users join or leave a thread. `added_members` are `EDA.Channel.ThreadMember` structs,
  each with its guild member when the guild member intent is on.
  """
  use EDA.Event.Access
  defstruct [:id, :guild_id, :member_count, :added_members, :removed_member_ids]

  @type t :: %__MODULE__{
          id: String.t() | nil,
          guild_id: String.t() | nil,
          member_count: integer() | nil,
          added_members: [EDA.Channel.ThreadMember.t()] | nil,
          removed_member_ids: [String.t()] | nil
        }
  @doc "Converts a raw Discord payload into this event struct."
  @spec from_raw(map()) :: t()
  def from_raw(raw) when is_map(raw) do
    %__MODULE__{
      id: raw["id"],
      guild_id: raw["guild_id"],
      member_count: raw["member_count"],
      added_members: parse_members(raw["added_members"]),
      removed_member_ids: raw["removed_member_ids"]
    }
  end

  defp parse_members(nil), do: nil

  defp parse_members(list) when is_list(list),
    do: Enum.map(list, &EDA.Channel.ThreadMember.from_raw/1)
end
