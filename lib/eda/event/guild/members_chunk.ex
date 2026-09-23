defmodule EDA.Event.GuildMembersChunk do
  @moduledoc """
  Dispatched in response to a guild members request.

  `members` are `EDA.Member` structs and `presences`, sent when the request asked for them,
  `EDA.Event.PresenceUpdate` structs; both carry the chunk's `guild_id`.
  """
  use EDA.Event.Access
  defstruct [:guild_id, :members, :chunk_index, :chunk_count, :not_found, :presences, :nonce]

  @type t :: %__MODULE__{
          guild_id: String.t() | nil,
          members: [EDA.Member.t()] | nil,
          chunk_index: integer() | nil,
          chunk_count: integer() | nil,
          not_found: [String.t()] | nil,
          presences: [EDA.Event.PresenceUpdate.t()] | nil,
          nonce: String.t() | nil
        }
  @doc "Converts a raw Discord payload into this event struct."
  @spec from_raw(map()) :: t()
  def from_raw(raw) when is_map(raw) do
    %__MODULE__{
      guild_id: raw["guild_id"],
      members: parse(raw["members"], &%{EDA.Member.from_raw(&1) | guild_id: raw["guild_id"]}),
      chunk_index: raw["chunk_index"],
      chunk_count: raw["chunk_count"],
      not_found: raw["not_found"],
      presences:
        parse(
          raw["presences"],
          &EDA.Event.PresenceUpdate.from_raw(Map.put(&1, "guild_id", raw["guild_id"]))
        ),
      nonce: raw["nonce"]
    }
  end

  defp parse(nil, _from_raw), do: nil
  defp parse(list, from_raw) when is_list(list), do: Enum.map(list, from_raw)
end
