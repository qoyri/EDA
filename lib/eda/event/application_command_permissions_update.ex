defmodule EDA.Event.ApplicationCommandPermissionsUpdate do
  @moduledoc "Dispatched when who may use one of the app's commands in a guild changes."
  use EDA.Event.Access

  defstruct [:permissions]

  @type t :: %__MODULE__{permissions: EDA.Command.Permissions.t()}

  @doc "Converts a raw Discord payload into this event struct."
  @spec from_raw(map()) :: t()
  def from_raw(raw) when is_map(raw),
    do: %__MODULE__{permissions: EDA.Command.Permissions.from_raw(raw)}
end
