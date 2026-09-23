defmodule EDA.Event.EntitlementDelete do
  @moduledoc """
  Sent when an entitlement is deleted: a refund, or removal by Discord or the app. Not sent on
  expiry. Delivers an `EDA.Entitlement`, not a struct of its own.

  The consumer receives `{:ENTITLEMENT_DELETE, %EDA.Entitlement{}}`. This module only parses the
  payload.
  """

  @doc "Parses the `ENTITLEMENT_DELETE` payload into an `EDA.Entitlement`."
  @spec from_raw(map()) :: EDA.Entitlement.t()
  def from_raw(raw) when is_map(raw), do: EDA.Entitlement.from_raw(raw)
end
