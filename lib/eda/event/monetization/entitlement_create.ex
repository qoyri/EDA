defmodule EDA.Event.EntitlementCreate do
  @moduledoc "Dispatched when a user or guild gains an entitlement to one of the app's SKUs."
  use EDA.Event.Access

  defstruct [:entitlement]

  @type t :: %__MODULE__{entitlement: EDA.Entitlement.t()}

  @doc "Converts a raw Discord payload into this event struct."
  @spec from_raw(map()) :: t()
  def from_raw(raw) when is_map(raw), do: %__MODULE__{entitlement: EDA.Entitlement.from_raw(raw)}
end
