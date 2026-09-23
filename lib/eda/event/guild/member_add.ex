defmodule EDA.Event.GuildMemberAdd do
  @moduledoc """
  Sent when a user joins a guild. Delivers an `EDA.Member`, not a struct of its own.

  The consumer receives `{:GUILD_MEMBER_ADD, %EDA.Member{}}` with every field Discord sent — `flags`,
  `premium_since`, `communication_disabled_until`, the member's decoration and nameplate — and
  `guild_id` set, so `EDA.Member.flags/1`, `EDA.Permission.for_member/2` and the rest take it as
  is. This module only parses the payload.
  """

  @doc "Parses the `GUILD_MEMBER_ADD` payload into an `EDA.Member`."
  @spec from_raw(map()) :: EDA.Member.t()
  def from_raw(raw) when is_map(raw), do: EDA.Member.from_raw(raw)
end
