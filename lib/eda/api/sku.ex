defmodule EDA.API.SKU do
  @moduledoc """
  REST API endpoints for Discord SKUs (monetization).

  SKUs represent premium offerings for your application (subscriptions,
  consumables, durables).
  """

  import EDA.HTTP.Client

  @doc """
  Lists all SKUs for the current application.

  Returns `{:ok, [sku]}` where each SKU has `id`, `type`, `name`, `slug`, `flags`.

  ## Examples

      {:ok, skus} = EDA.API.SKU.list()
  """
  @spec list() :: {:ok, [map()]} | {:error, term()}
  def list do
    EDA.HTTP.Client.get("/applications/#{app_id()}/skus")
  end
end
