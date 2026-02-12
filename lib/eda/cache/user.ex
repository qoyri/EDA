defmodule EDA.Cache.User do
  @moduledoc """
  ETS-based cache for Discord users.

  Provides O(1) lookups for user data.
  """

  use GenServer

  @table :eda_users

  # Client API

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @doc """
  Gets a user from the cache.
  """
  @spec get(String.t() | integer()) :: map() | nil
  def get(user_id) do
    case :ets.lookup(@table, to_string(user_id)) do
      [{_, user}] -> user
      [] -> nil
    end
  end

  @doc """
  Gets all cached users.
  """
  @spec all() :: [map()]
  def all do
    :ets.tab2list(@table)
    |> Enum.map(fn {_, user} -> user end)
  end

  @doc """
  Creates or replaces a user in the cache.
  """
  @spec create(map()) :: map()
  def create(user) do
    user_id = to_string(user["id"])
    :ets.insert(@table, {user_id, user})
    user
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
        :ets.insert(@table, {user_id, updated})
        updated
    end
  end

  @doc """
  Deletes a user from the cache.
  """
  @spec delete(String.t() | integer()) :: :ok
  def delete(user_id) do
    :ets.delete(@table, to_string(user_id))
    :ok
  end

  @doc """
  Returns the number of cached users.
  """
  @spec count() :: non_neg_integer()
  def count do
    :ets.info(@table, :size)
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    table = :ets.new(@table, [:set, :public, :named_table, read_concurrency: true])
    {:ok, %{table: table}}
  end
end
