defmodule EDA.Event.SubscriptionCreate do
  @moduledoc """
  Sent when a premium app subscription is created. Its status may still be inactive: grant perks
  on entitlements, not here. Delivers an `EDA.Subscription`, not a struct of its own.

  The consumer receives `{:SUBSCRIPTION_CREATE, %EDA.Subscription{}}`. This module only parses the
  payload.
  """

  @doc "Parses the `SUBSCRIPTION_CREATE` payload into an `EDA.Subscription`."
  @spec from_raw(map()) :: EDA.Subscription.t()
  def from_raw(raw) when is_map(raw), do: EDA.Subscription.from_raw(raw)
end
