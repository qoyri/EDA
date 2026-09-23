defmodule EDA.Message.RoleSubscriptionData do
  @moduledoc """
  What a `:role_subscription_purchase` message announces: the tier bought, for how many months
  in total, and whether it renews an earlier subscription.
  """

  use EDA.Event.Access

  defstruct [:role_subscription_listing_id, :tier_name, :total_months_subscribed, :is_renewal]

  @type t :: %__MODULE__{
          role_subscription_listing_id: String.t() | nil,
          tier_name: String.t() | nil,
          total_months_subscribed: non_neg_integer() | nil,
          is_renewal: boolean() | nil
        }

  @doc false
  @spec from_raw(map() | nil) :: t() | nil
  def from_raw(nil), do: nil

  def from_raw(raw) when is_map(raw) do
    %__MODULE__{
      role_subscription_listing_id: raw["role_subscription_listing_id"],
      tier_name: raw["tier_name"],
      total_months_subscribed: raw["total_months_subscribed"],
      is_renewal: raw["is_renewal"]
    }
  end
end
