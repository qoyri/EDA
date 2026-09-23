defmodule EDA.Event.GuildCreate do
  @moduledoc """
  Delivers an `EDA.Guild`, not a struct of its own. It is also delivered as `GUILD_AVAILABLE` for a guild that finishes loading at startup, and carries what only `GUILD_CREATE` has — see the section on it in `EDA.Guild`.

  The consumer receives `{:GUILD_CREATE, %EDA.Guild{}}` with every field Discord sent. This module
  only parses the payload.
  """

  @doc "Parses the `GUILD_CREATE` payload into an `EDA.Guild`."
  @spec from_raw(map()) :: EDA.Guild.t()
  def from_raw(raw) when is_map(raw), do: EDA.Guild.from_raw(raw)
end
