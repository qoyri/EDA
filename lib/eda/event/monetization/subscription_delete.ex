defmodule EDA.Event.SubscriptionDelete do
  @moduledoc """
  Sent when a premium app subscription is deleted. Delivers an `EDA.Subscription`, not a struct of
  its own.

  The consumer receives `{:SUBSCRIPTION_DELETE, %EDA.Subscription{}}`. This module only parses the
  payload.
  """

  @doc "Parses the `SUBSCRIPTION_DELETE` payload into an `EDA.Subscription`."
  @spec from_raw(map()) :: EDA.Subscription.t()
  def from_raw(raw) when is_map(raw), do: EDA.Subscription.from_raw(raw)
end
