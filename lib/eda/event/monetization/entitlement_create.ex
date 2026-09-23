defmodule EDA.Event.EntitlementCreate do
  @moduledoc """
  Sent when a user or guild gains an entitlement to one of the app's SKUs. Delivers an
  `EDA.Entitlement`, not a struct of its own.

  The consumer receives `{:ENTITLEMENT_CREATE, %EDA.Entitlement{}}`. This module only parses the
  payload.
  """

  @doc "Parses the `ENTITLEMENT_CREATE` payload into an `EDA.Entitlement`."
  @spec from_raw(map()) :: EDA.Entitlement.t()
  def from_raw(raw) when is_map(raw), do: EDA.Entitlement.from_raw(raw)
end
