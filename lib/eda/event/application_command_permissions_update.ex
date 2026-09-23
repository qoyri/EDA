defmodule EDA.Event.ApplicationCommandPermissionsUpdate do
  @moduledoc """
  Sent when who may use one of the app's commands in a guild changes. Delivers an
  `EDA.Command.Permissions`, not a struct of its own.

  The consumer receives `{:APPLICATION_COMMAND_PERMISSIONS_UPDATE, %EDA.Command.Permissions{}}`.
  This module only parses the payload.
  """

  @doc "Parses the `APPLICATION_COMMAND_PERMISSIONS_UPDATE` payload into an `EDA.Command.Permissions`."
  @spec from_raw(map()) :: EDA.Command.Permissions.t()
  def from_raw(raw) when is_map(raw), do: EDA.Command.Permissions.from_raw(raw)
end
