defmodule EDA.Event.SubscriptionDelete do
  @moduledoc "Dispatched when a premium app subscription is deleted."
  use EDA.Event.Access

  defstruct [:subscription]

  @type t :: %__MODULE__{subscription: EDA.Subscription.t()}

  @doc "Converts a raw Discord payload into this event struct."
  @spec from_raw(map()) :: t()
  def from_raw(raw) when is_map(raw),
    do: %__MODULE__{subscription: EDA.Subscription.from_raw(raw)}
end
