defmodule EDA.API.Entitlement do
  @moduledoc """
  REST API endpoints for Discord Entitlements (monetization).

  Entitlements represent a user or guild's access to a specific SKU
  (purchases, subscriptions, gifts).
  """

  import EDA.HTTP.Client

  @doc """
  Lists entitlements for the current application.

  ## Options

    * `:user_id` — filter by user
    * `:guild_id` — filter by guild
    * `:sku_ids` — comma-separated SKU IDs to filter
    * `:before` — pagination cursor (snowflake)
    * `:after` — pagination cursor (snowflake)
    * `:limit` — max results (1-100, default 100)
    * `:exclude_ended` — exclude ended entitlements (boolean)
    * `:exclude_deleted` — exclude deleted entitlements (boolean)

  ## Examples

      {:ok, entitlements} = EDA.API.Entitlement.list()
      {:ok, entitlements} = EDA.API.Entitlement.list(user_id: "123", exclude_ended: true)
  """
  @spec list(keyword()) :: {:ok, [map()]} | {:error, term()}
  def list(opts \\ []) do
    EDA.HTTP.Client.get(
      with_query("/applications/#{app_id()}/entitlements", opts, [
        :user_id,
        :sku_ids,
        :before,
        :after,
        :limit,
        :guild_id,
        :exclude_ended,
        :exclude_deleted
      ])
    )
  end

  @doc """
  Gets a specific entitlement by ID.

  ## Examples

      {:ok, entitlement} = EDA.API.Entitlement.get("entitlement_id")
  """
  @spec get(String.t() | integer()) :: {:ok, map()} | {:error, term()}
  def get(entitlement_id) do
    EDA.HTTP.Client.get("/applications/#{app_id()}/entitlements/#{entitlement_id}")
  end

  @doc """
  Marks a consumable entitlement as consumed.

  Only valid for one-time purchase consumable SKUs.

  ## Examples

      :ok = EDA.API.Entitlement.consume("entitlement_id")
  """
  @spec consume(String.t() | integer()) :: :ok | {:error, term()}
  def consume(entitlement_id) do
    case post("/applications/#{app_id()}/entitlements/#{entitlement_id}/consume", %{}) do
      {:ok, _} -> :ok
      error -> error
    end
  end

  @doc """
  Creates a test entitlement for development/testing.

  ## Options

    * `:sku_id` (required) — the SKU to grant
    * `:owner_id` (required) — the user or guild ID to grant to
    * `:owner_type` (required) — `1` for guild, `2` for user

  ## Examples

      {:ok, entitlement} = EDA.API.Entitlement.create_test(%{
        sku_id: "sku_id",
        owner_id: "user_id",
        owner_type: 2
      })
  """
  @spec create_test(map() | keyword()) :: {:ok, map()} | {:error, term()}
  def create_test(opts) do
    body = Map.new(opts)
    check_options!(body, [:sku_id, :owner_id, :owner_type], "EDA.API.Entitlement.create_test/1")
    post("/applications/#{app_id()}/entitlements", body)
  end

  @doc """
  Deletes a test entitlement.

  ## Examples

      :ok = EDA.API.Entitlement.delete_test("entitlement_id")
  """
  @spec delete_test(String.t() | integer()) :: :ok | {:error, term()}
  def delete_test(entitlement_id) do
    case EDA.HTTP.Client.delete("/applications/#{app_id()}/entitlements/#{entitlement_id}") do
      {:ok, _} -> :ok
      error -> error
    end
  end
end
