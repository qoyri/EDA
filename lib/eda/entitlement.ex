defmodule EDA.Entitlement do
  @moduledoc """
  A user's or a guild's access to one of the app's SKUs — what a premium app checks before
  granting a perk.

  Arrives with the `ENTITLEMENT_CREATE`, `_UPDATE` and `_DELETE` events and from
  `EDA.API.Entitlement`. Discord's own advice is to grant perks on entitlements, not on
  subscription status: see `active?/1`.

  An entitlement is **not** deleted when it expires; `ends_at` passes instead. Deletion happens
  on a refund, or when Discord or the app removes it.
  """

  use EDA.Event.Access

  defstruct [
    :id,
    :sku_id,
    :application_id,
    :user_id,
    :guild_id,
    :type,
    :starts_at,
    :ends_at,
    deleted: false,
    consumed: nil
  ]

  @type type ::
          :purchase
          | :premium_subscription
          | :developer_gift
          | :test_mode_purchase
          | :free_purchase
          | :user_gift
          | :premium_purchase
          | :application_subscription

  @type t :: %__MODULE__{
          id: String.t() | nil,
          sku_id: String.t() | nil,
          application_id: String.t() | nil,
          user_id: String.t() | nil,
          guild_id: String.t() | nil,
          type: type() | integer() | nil,
          starts_at: DateTime.t() | nil,
          ends_at: DateTime.t() | nil,
          deleted: boolean(),
          consumed: boolean() | nil
        }

  @types %{
    1 => :purchase,
    2 => :premium_subscription,
    3 => :developer_gift,
    4 => :test_mode_purchase,
    5 => :free_purchase,
    6 => :user_gift,
    7 => :premium_purchase,
    8 => :application_subscription
  }

  @doc "Converts a raw entitlement object into this struct."
  @spec from_raw(map()) :: t()
  def from_raw(raw) when is_map(raw) do
    %__MODULE__{
      id: raw["id"],
      sku_id: raw["sku_id"],
      application_id: raw["application_id"],
      user_id: raw["user_id"],
      guild_id: raw["guild_id"],
      type: Map.get(@types, raw["type"], raw["type"]),
      starts_at: parse_time(raw["starts_at"]),
      ends_at: parse_time(raw["ends_at"]),
      deleted: raw["deleted"] || false,
      consumed: raw["consumed"]
    }
  end

  @doc """
  Whether the entitlement grants access right now: not deleted, already started, not yet ended.
  A missing start or end date is no bound.

      iex> EDA.Entitlement.active?(%EDA.Entitlement{deleted: false})
      true

      iex> EDA.Entitlement.active?(%EDA.Entitlement{ends_at: ~U[2020-01-01 00:00:00Z]})
      false
  """
  @spec active?(t(), DateTime.t()) :: boolean()
  def active?(%__MODULE__{} = entitlement, now \\ DateTime.utc_now()) do
    not entitlement.deleted and
      (is_nil(entitlement.starts_at) or DateTime.compare(entitlement.starts_at, now) != :gt) and
      (is_nil(entitlement.ends_at) or DateTime.compare(entitlement.ends_at, now) == :gt)
  end

  defp parse_time(value), do: EDA.Timestamp.parse(value)
end
