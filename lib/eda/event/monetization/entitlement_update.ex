defmodule EDA.Event.EntitlementUpdate do
  @moduledoc "Dispatched when an entitlement changes — a subscription renewing sets a new `ends_at`."
  use EDA.Event.Access

  defstruct [:entitlement]

  @type t :: %__MODULE__{entitlement: EDA.Entitlement.t()}

  @doc "Converts a raw Discord payload into this event struct."
  @spec from_raw(map()) :: t()
  def from_raw(raw) when is_map(raw), do: %__MODULE__{entitlement: EDA.Entitlement.from_raw(raw)}
end
