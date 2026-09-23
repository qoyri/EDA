defmodule EDA.Event.ThreadMemberUpdate do
  @moduledoc """
  Sent when the bot's own membership of a thread changes. Delivers an `EDA.Channel.ThreadMember`
  with its `guild_id`, not a struct of its own.

  The consumer receives `{:THREAD_MEMBER_UPDATE, %EDA.Channel.ThreadMember{}}`. This module only
  parses the payload.
  """

  @doc "Parses the `THREAD_MEMBER_UPDATE` payload into an `EDA.Channel.ThreadMember`."
  @spec from_raw(map()) :: EDA.Channel.ThreadMember.t()
  def from_raw(raw) when is_map(raw),
    do: %{EDA.Channel.ThreadMember.from_raw(raw) | guild_id: raw["guild_id"]}
end
