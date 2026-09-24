defmodule EDA.Cache.User do
  @moduledoc """
  ETS-based cache for Discord users.

  Provides O(1) lookups for user data.
  """

  use GenServer

  @table :eda_users
  # The fields only REST returns, for the users a REST result carried them for: {id, banner,
  # accent_color}. Kept apart so that caching a user from the gateway checks a small table rather
  # than copying the whole cached user out to compare. An entry may outlive its user's eviction;
  # it then only restores what REST last said.
  @rest_only :eda_users_rest_only
  @cache_name :users

  # Client API

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @doc """
  Gets a user from the cache.
  """
  @spec get(String.t() | integer()) :: EDA.User.t() | nil
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
  @spec all() :: [EDA.User.t()]
  def all do
    adapter().all(@table)
  end

  @doc """
  Creates or replaces a user in the cache.
  """
  @spec create(map() | EDA.User.t()) :: EDA.User.t()
  def create(user) do
    user = to_struct(user)
    user_id = to_string(user.id)
    if put(user, user_id) == :cache, do: remember_rest_only(user, user_id)
    user
  end

  @doc """
  Caches a user as the gateway sends it, keeping what the gateway never sends.

  `EDA.User.rest_only_fields/0` (the banner and accent colour) are taken from the cached entry
  when the incoming user has none, so a REST fetch is not undone by the user's next event.
  `create/1` replaces the entry whole.
  """
  @spec merge(map() | EDA.User.t()) :: EDA.User.t()
  def merge(user) do
    user = to_struct(user)
    user_id = to_string(user.id)

    user =
      case :ets.lookup(@rest_only, user_id) do
        [{_, banner, accent_color}] ->
          %{user | banner: user.banner || banner, accent_color: user.accent_color || accent_color}

        [] ->
          user
      end

    put(user, user_id)
    user
  end

  defp remember_rest_only(%EDA.User{banner: nil, accent_color: nil}, user_id),
    do: :ets.delete(@rest_only, user_id)

  defp remember_rest_only(user, user_id),
    do: :ets.insert(@rest_only, {user_id, user.banner, user.accent_color})

  defp put(user, user_id) do
    case EDA.Cache.Policy.check(EDA.Cache.Config.policy(@cache_name), :user, user_id, user) do
      :cache ->
        adapter().put(@table, user_id, user)
        EDA.Cache.Evictor.touch(@table, user_id)
        :telemetry.execute([:eda, :cache, :write], %{count: 1}, %{cache: @cache_name})
        :cache

      :skip ->
        :telemetry.execute([:eda, :cache, :skip], %{count: 1}, %{cache: @cache_name})
        :skip
    end
  end

  @doc """
  Updates a user in the cache.
  """
  @spec update(String.t() | integer(), map()) :: EDA.User.t() | nil
  def update(user_id, updates) do
    user_id = to_string(user_id)

    case get(user_id) do
      nil ->
        nil

      existing ->
        updated = EDA.Entity.patch(existing, updates)
        adapter().put(@table, user_id, updated)
        remember_rest_only(updated, user_id)
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
    :ets.delete(@rest_only, key)
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
    :ets.new(@rest_only, [:named_table, :public, :set, read_concurrency: true])
    {:ok, %{table: @table}}
  end

  defp adapter, do: EDA.Cache.Adapter.current()

  # The cache keeps a user without the partial member Discord attaches to a mention.
  defp to_struct(%EDA.User{} = user), do: %{user | member: nil}
  defp to_struct(raw) when is_map(raw), do: raw |> Map.delete("member") |> EDA.User.from_raw()
end
