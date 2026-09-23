defmodule EDA.Event.GuildRoleCreate do
  @moduledoc """
  Sent when a guild role is created. Delivers an `EDA.Role` with its `guild_id`, not a struct of
  its own.

  The consumer receives `{:GUILD_ROLE_CREATE, %EDA.Role{}}`. This module only parses the payload.
  """

  @doc "Parses the `GUILD_ROLE_CREATE` payload into an `EDA.Role`."
  @spec from_raw(map()) :: EDA.Role.t()
  def from_raw(raw) when is_map(raw),
    do: %{EDA.Role.from_raw(raw["role"] || %{}) | guild_id: raw["guild_id"]}
end
