defmodule EDA.Cache.User do
  @moduledoc """
  ETS-based cache for Discord users.

  Provides O(1) lookups for user data.
  """

  use GenServer

  @table :eda_users
  @cache_name :users

  # Client API

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @doc """
  Gets a user from the cache.
  """
  @spec get(String.t() | integer()) :: map() | nil
  def get(user_id) do
    case adapter().get(@table, to_string(user_id)) do
      nil ->
        :telemetry.execute([:eda, :cache, :miss], %{count: 1}, %{cache: @cache_name})
        nil

      user ->
        :telemetry.execute([:eda, :cache, :hit], %{count: 1}, %{cache: @cache_name})
        user
    end
  end

  @doc """
  Gets all cached users.
  """
  @spec all() :: [map()]
  def all do
    adapter().all(@table)
  end

  @doc """
  Creates or replaces a user in the cache.
  """
  @spec create(map()) :: map()
  def create(user) do
    user_id = to_string(user["id"])

    case EDA.Cache.Policy.check(EDA.Cache.Config.policy(@cache_name), :user, user_id, user) do
      :cache ->
        adapter().put(@table, user_id, user)
        EDA.Cache.Evictor.touch(@table, user_id)
        :telemetry.execute([:eda, :cache, :write], %{count: 1}, %{cache: @cache_name})
        user

      :skip ->
        :telemetry.execute([:eda, :cache, :skip], %{count: 1}, %{cache: @cache_name})
        user
    end
  end

  @doc """
  Updates a user in the cache.
  """
  @spec update(String.t() | integer(), map()) :: map() | nil
  def update(user_id, updates) do
    user_id = to_string(user_id)

    case get(user_id) do
      nil ->
        nil

      existing ->
        updated = Map.merge(existing, updates)
        adapter().put(@table, user_id, updated)
        updated
    end
  end

  @doc """
  Deletes a user from the cache.
  """
  @spec delete(String.t() | integer()) :: :ok
  def delete(user_id) do
    key = to_string(user_id)
    adapter().delete(@table, key)
    EDA.Cache.Evictor.remove(@table, key)
    :ok
  end

  @doc """
  Returns the number of cached users.
  """
  @spec count() :: non_neg_integer()
  def count do
    adapter().count(@table)
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    :ok = adapter().init(@table, [])
    {:ok, %{table: @table}}
  end

  defp adapter, do: EDA.Cache.Adapter.current()
end
