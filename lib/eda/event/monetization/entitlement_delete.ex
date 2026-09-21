defmodule EDA.Event.EntitlementDelete do
  @moduledoc "Dispatched when an entitlement is deleted: a refund, or removal by Discord or the app. Not sent on expiry."
  use EDA.Event.Access

  defstruct [:entitlement]

  @type t :: %__MODULE__{entitlement: EDA.Entitlement.t()}

  @doc "Converts a raw Discord payload into this event struct."
  @spec from_raw(map()) :: t()
  def from_raw(raw) when is_map(raw), do: %__MODULE__{entitlement: EDA.Entitlement.from_raw(raw)}
end
