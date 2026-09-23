defmodule EDA.Subscription do
  @moduledoc """
  Represents a Discord subscription — a user's recurring access to one or more SKUs.

  > #### Do not hardcode the status integers {: .error}
  >
  > Discord **renumbered** this enum on 2026-06-16: `INACTIVE` and `ENDING` swapped places.
  > Code that compared `status == 1` kept running and started meaning the opposite thing.
  > Use `status/1`, which returns `:active`, `:inactive` or `:ending`.

  ## Status is not a permission

  A subscription's status says what will happen at the end of the period, not what the user
  may do right now. Discord is explicit that a subscription "can be `ACTIVE` outside its
  current period or `INACTIVE` within its current period" — a failed payment keeps it active
  while it retries, and a chargeback makes it inactive mid-period.

  **Entitlements decide access, not this.** Read `EDA.API.Entitlement` for that question and
  treat the status as billing information.
  """
  use EDA.Event.Access
  @statuses %{0 => :active, 1 => :inactive, 2 => :ending}

  defstruct [
    :id,
    :user_id,
    :sku_ids,
    :entitlement_ids,
    :renewal_sku_ids,
    :current_period_start,
    :current_period_end,
    :status,
    :canceled_at,
    :country
  ]

  @type t :: %__MODULE__{
          id: String.t() | nil,
          user_id: String.t() | nil,
          sku_ids: [String.t()] | nil,
          entitlement_ids: [String.t()] | nil,
          renewal_sku_ids: [String.t()] | nil,
          current_period_start: DateTime.t() | nil,
          current_period_end: DateTime.t() | nil,
          status: :active | :inactive | :ending | integer() | nil,
          canceled_at: DateTime.t() | nil,
          country: String.t() | nil
        }

  @spec from_raw(map()) :: t()
  def from_raw(raw) when is_map(raw) do
    %__MODULE__{
      id: raw["id"],
      user_id: raw["user_id"],
      sku_ids: raw["sku_ids"],
      entitlement_ids: raw["entitlement_ids"],
      renewal_sku_ids: raw["renewal_sku_ids"],
      current_period_start: EDA.Timestamp.parse(raw["current_period_start"]),
      current_period_end: EDA.Timestamp.parse(raw["current_period_end"]),
      status: EDA.Enum.name(@statuses, raw["status"]),
      canceled_at: EDA.Timestamp.parse(raw["canceled_at"]),
      country: raw["country"]
    }
  end

  # ── Status ──

  @typedoc "A subscription status name."
  @type status :: :active | :inactive | :ending | :unknown

  @doc """
  Names the subscription's status.

    * `:active` — running and scheduled to renew
    * `:inactive` — not running and not being charged
    * `:ending` — still running, but it will not renew

  An integer Discord has since added comes back as `:unknown` rather than crashing a
  `case`.

  ## Examples

      iex> EDA.Subscription.status(%EDA.Subscription{status: 0})
      :active

      iex> EDA.Subscription.status(%{"status" => 2})
      :ending

      iex> EDA.Subscription.status(%EDA.Subscription{status: 99})
      :unknown

      iex> EDA.Subscription.status(nil)
      :unknown
  """
  @spec status(t() | map() | integer() | nil) :: status()
  def status(%__MODULE__{status: value}), do: status(value)
  def status(%{"status" => value}), do: status(value)
  def status(value) when is_integer(value), do: Map.get(@statuses, value, :unknown)
  def status(value) when value in [:active, :inactive, :ending], do: value
  def status(_other), do: :unknown

  @doc """
  Returns the integer Discord uses for a status name, or `nil` for an unknown name.

  Useful for filtering a list without writing the numbers down.

  ## Examples

      iex> EDA.Subscription.status_value(:ending)
      2

      iex> EDA.Subscription.status_value(:nonsense)
      nil
  """
  @spec status_value(status()) :: integer() | nil
  def status_value(name) when is_atom(name) do
    Enum.find_value(@statuses, fn {value, status} -> if status == name, do: value end)
  end

  @doc """
  Returns `true` if the subscription will renew at the end of the current period.

  Only `:active` renews. `:ending` is still running but will stop, which is the distinction
  worth acting on — it is the state to send a "your subscription ends on …" message about.

  ## Examples

      iex> EDA.Subscription.renewing?(%EDA.Subscription{status: 0})
      true

      iex> EDA.Subscription.renewing?(%EDA.Subscription{status: 2})
      false
  """
  @spec renewing?(t() | map() | integer() | nil) :: boolean()
  def renewing?(subscription), do: status(subscription) == :active

  @doc """
  Returns `true` if the subscription has been cancelled.

  Reads `canceled_at`, which is set as soon as the user cancels — the subscription is then
  `:ending` until the period runs out, and `:inactive` after.

  ## Examples

      iex> EDA.Subscription.canceled?(%EDA.Subscription{canceled_at: "2026-09-19T12:00:00Z"})
      true

      iex> EDA.Subscription.canceled?(%EDA.Subscription{})
      false
  """
  @spec canceled?(t() | map()) :: boolean()
  def canceled?(%__MODULE__{canceled_at: nil}), do: false
  def canceled?(%__MODULE__{}), do: true
  def canceled?(%{"canceled_at" => nil}), do: false
  def canceled?(%{"canceled_at" => _value}), do: true
  def canceled?(_other), do: false

  @doc """
  Returns `true` if the SKUs will change at renewal.

  `renewal_sku_ids` is `nil` while nothing is changing, and carries the new list once the
  user has switched plan — an upgrade or downgrade that has not taken effect yet.

  ## Examples

      iex> EDA.Subscription.changing_plan?(%EDA.Subscription{sku_ids: ["1"], renewal_sku_ids: ["2"]})
      true

      iex> EDA.Subscription.changing_plan?(%EDA.Subscription{sku_ids: ["1"], renewal_sku_ids: nil})
      false
  """
  @spec changing_plan?(t() | map()) :: boolean()
  def changing_plan?(%__MODULE__{renewal_sku_ids: nil}), do: false

  def changing_plan?(%__MODULE__{sku_ids: sku_ids, renewal_sku_ids: renewal}),
    do: Enum.sort(renewal || []) != Enum.sort(sku_ids || [])

  def changing_plan?(raw) when is_map(raw), do: raw |> from_raw() |> changing_plan?()

  # ── Entity Manager ──

  use EDA.Entity

  @doc """
  Fetches one subscription for a SKU. Returns a `t:t/0`.

  Named `fetch_subscription/2` rather than `fetch/2` because `Access.fetch/2` owns that
  arity.
  """
  @spec fetch_subscription(String.t() | integer(), String.t() | integer()) ::
          {:ok, t()} | {:error, term()}
  def fetch_subscription(sku_id, subscription_id) do
    EDA.API.Subscription.get(sku_id, subscription_id) |> parse_response()
  end

  @doc """
  Lists a SKU's subscriptions as structs.

  Takes the same options as `EDA.API.Subscription.list/2` — `:user_id`, `:before`,
  `:after`, `:limit`.
  """
  @spec list(String.t() | integer(), keyword()) :: {:ok, [t()]} | {:error, term()}
  def list(sku_id, opts \\ []) do
    case EDA.API.Subscription.list(sku_id, opts) do
      {:ok, list} when is_list(list) -> {:ok, Enum.map(list, &from_raw/1)}
      {:error, _} = err -> err
    end
  end
end
