defmodule EDA.Event.SubscriptionUpdate do
  @moduledoc """
  Sent when a premium app subscription changes, such as becoming active or ending. Delivers an
  `EDA.Subscription`, not a struct of its own.

  The consumer receives `{:SUBSCRIPTION_UPDATE, %EDA.Subscription{}}`. This module only parses the
  payload.
  """

  @doc "Parses the `SUBSCRIPTION_UPDATE` payload into an `EDA.Subscription`."
  @spec from_raw(map()) :: EDA.Subscription.t()
  def from_raw(raw) when is_map(raw), do: EDA.Subscription.from_raw(raw)
end
