defmodule EDA.Event.EntitlementUpdate do
  @moduledoc """
  Sent when an entitlement changes — a subscription renewing sets a new `ends_at`. Delivers an
  `EDA.Entitlement`, not a struct of its own.

  The consumer receives `{:ENTITLEMENT_UPDATE, %EDA.Entitlement{}}`. This module only parses the
  payload.
  """

  @doc "Parses the `ENTITLEMENT_UPDATE` payload into an `EDA.Entitlement`."
  @spec from_raw(map()) :: EDA.Entitlement.t()
  def from_raw(raw) when is_map(raw), do: EDA.Entitlement.from_raw(raw)
end
