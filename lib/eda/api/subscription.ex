defmodule EDA.API.Subscription do
  @moduledoc """
  REST API endpoints for Discord Subscriptions (monetization).

  Subscriptions represent recurring access to a SKU for a user.
  """

  import EDA.HTTP.Client

  @doc """
  Lists subscriptions for a given SKU.

  ## Options

    * `:user_id` — filter by user (required unless in OAuth context)
    * `:before` — pagination cursor (snowflake)
    * `:after` — pagination cursor (snowflake)
    * `:limit` — max results, 1-100 (default 50)

  ## Examples

      {:ok, subs} = EDA.API.Subscription.list("sku_id", user_id: "user_id")
  """
  @spec list(String.t() | integer(), keyword()) :: {:ok, [map()]} | {:error, term()}
  def list(sku_id, opts \\ []) do
    EDA.HTTP.Client.get(with_query("/skus/#{sku_id}/subscriptions", opts))
  end

  @doc """
  Gets a specific subscription by ID.

  ## Examples

      {:ok, sub} = EDA.API.Subscription.get("sku_id", "subscription_id")
  """
  @spec get(String.t() | integer(), String.t() | integer()) :: {:ok, map()} | {:error, term()}
  def get(sku_id, subscription_id) do
    EDA.HTTP.Client.get("/skus/#{sku_id}/subscriptions/#{subscription_id}")
  end
end
