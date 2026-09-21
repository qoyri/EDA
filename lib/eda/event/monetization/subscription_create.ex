defmodule EDA.Event.SubscriptionCreate do
  @moduledoc "Dispatched when a premium app subscription is created. Its status may still be inactive: grant perks on entitlements, not here."
  use EDA.Event.Access

  defstruct [:subscription]

  @type t :: %__MODULE__{subscription: EDA.Subscription.t()}

  @doc "Converts a raw Discord payload into this event struct."
  @spec from_raw(map()) :: t()
  def from_raw(raw) when is_map(raw),
    do: %__MODULE__{subscription: EDA.Subscription.from_raw(raw)}
end
