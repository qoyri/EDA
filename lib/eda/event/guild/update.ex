defmodule EDA.Event.GuildUpdate do
  @moduledoc """
  Delivers an `EDA.Guild`, not a struct of its own. The lists only `GUILD_CREATE` carries are `nil`.

  The consumer receives `{:GUILD_UPDATE, %EDA.Guild{}}` with every field Discord sent. This module
  only parses the payload.
  """

  @doc "Parses the `GUILD_UPDATE` payload into an `EDA.Guild`."
  @spec from_raw(map()) :: EDA.Guild.t()
  def from_raw(raw) when is_map(raw), do: EDA.Guild.from_raw(raw)
end
