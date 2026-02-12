defmodule EDA.Cache.Role do
  @moduledoc """
  ETS-based cache for Discord roles.

  Keyed by `role_id`. Each role includes its `guild_id` for filtering.

  Automatically populated from GUILD_CREATE and GUILD_ROLE_CREATE/UPDATE/DELETE events.
  """

  use GenServer

  @table :eda_roles

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @doc """
  Gets a role by ID.
  """
  @spec get(String.t() | integer()) :: map() | nil
  def get(role_id) do
    case :ets.lookup(@table, to_string(role_id)) do
      [{_, role}] -> role
      [] -> nil
    end
  end

  @doc """
  Gets all roles for a guild.
  """
  @spec for_guild(String.t() | integer()) :: [map()]
  def for_guild(guild_id) do
    guild_id = to_string(guild_id)

    all()
    |> Enum.filter(fn role -> role["guild_id"] == guild_id end)
  end

  @doc """
  Gets all cached roles.
  """
  @spec all() :: [map()]
  def all do
    :ets.tab2list(@table)
    |> Enum.map(fn {_, role} -> role end)
  end

  @doc """
  Creates or replaces a role in the cache.
  """
  @spec create(String.t(), map()) :: map()
  def create(guild_id, role) do
    role_id = to_string(role["id"])
    role_with_guild = Map.put(role, "guild_id", to_string(guild_id))
    :ets.insert(@table, {role_id, role_with_guild})
    role_with_guild
  end

  @doc """
  Updates a role in the cache.
  """
  @spec update(String.t(), map()) :: map() | nil
  def update(role_id, updates) do
    role_id = to_string(role_id)

    case get(role_id) do
      nil ->
        nil

      existing ->
        updated = Map.merge(existing, updates)
        :ets.insert(@table, {role_id, updated})
        updated
    end
  end

  @doc """
  Deletes a role from the cache.
  """
  @spec delete(String.t() | integer()) :: :ok
  def delete(role_id) do
    :ets.delete(@table, to_string(role_id))
    :ok
  end

  @doc """
  Removes all roles for a guild.
  """
  @spec delete_guild(String.t() | integer()) :: :ok
  def delete_guild(guild_id) do
    guild_id = to_string(guild_id)

    for_guild(guild_id)
    |> Enum.each(fn role -> :ets.delete(@table, role["id"]) end)

    :ok
  end

  @doc """
  Returns the total number of cached roles.
  """
  @spec count() :: non_neg_integer()
  def count do
    :ets.info(@table, :size)
  end

  @impl true
  def init(_opts) do
    table = :ets.new(@table, [:set, :public, :named_table, read_concurrency: true])
    {:ok, %{table: table}}
  end
end
