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
  def from_raw(%__MODULE__{} = parsed), do: parsed

  def from_raw(raw) when is_map(raw) do
    %__MODULE__{
      id: :maps.get("id", raw, nil),
      sku_id: :maps.get("sku_id", raw, nil),
      application_id: :maps.get("application_id", raw, nil),
      user_id: :maps.get("user_id", raw, nil),
      guild_id: :maps.get("guild_id", raw, nil),
      type: Map.get(@types, :maps.get("type", raw, nil), :maps.get("type", raw, nil)),
      starts_at: parse_time(:maps.get("starts_at", raw, nil)),
      ends_at: parse_time(:maps.get("ends_at", raw, nil)),
      deleted: :maps.get("deleted", raw, nil) || false,
      consumed: :maps.get("consumed", raw, nil)
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

  # ── Entity Manager ──

  use EDA.Entity

  @doc """
  Lists the app's entitlements. Takes the filters of `EDA.API.Entitlement.list/1`: `:user_id`,
  `:sku_ids`, `:guild_id`, `:before`, `:after`, `:limit`, `:exclude_ended`, `:exclude_deleted`.
  """
  @spec list(keyword()) :: {:ok, [t()]} | {:error, term()}
  def list(opts \\ []), do: EDA.API.Entitlement.list(opts) |> parse_list()

  @doc "Fetches one entitlement."
  @spec fetch(String.t() | integer()) :: {:ok, t()} | {:error, term()}
  def fetch(entitlement_id), do: EDA.API.Entitlement.get(entitlement_id) |> parse_response()

  @doc "Marks a consumable entitlement as used."
  @spec consume(t() | String.t() | integer()) :: :ok | {:error, term()}
  def consume(%__MODULE__{id: id}), do: consume(id)
  def consume(entitlement_id), do: EDA.API.Entitlement.consume(entitlement_id)

  @doc """
  Grants a test entitlement to a user or guild, for trying premium features without paying.
  Takes `:sku_id`, `:owner_id` and `:owner_type`.
  """
  @spec create_test(map() | keyword()) :: {:ok, t()} | {:error, term()}
  def create_test(opts), do: EDA.API.Entitlement.create_test(opts) |> parse_response()

  @doc "Deletes a test entitlement."
  @spec delete_test(t() | String.t() | integer()) :: :ok | {:error, term()}
  def delete_test(%__MODULE__{id: id}), do: delete_test(id)
  def delete_test(entitlement_id), do: EDA.API.Entitlement.delete_test(entitlement_id)

  defp parse_list({:ok, list}) when is_list(list), do: {:ok, Enum.map(list, &from_raw/1)}
  defp parse_list({:error, _} = err), do: err
end
