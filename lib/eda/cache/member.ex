defmodule EDA.Cache.Member do
  @moduledoc """
  ETS-based cache for Discord guild members.

  Stores guild-specific member data (nickname, roles, join date, etc.)
  separately from the global user cache. Keyed by `{guild_id, user_id}`.

  Automatically populated from GUILD_CREATE, GUILD_MEMBER_ADD/UPDATE/REMOVE,
  and VOICE_STATE_UPDATE events (which include a member object).
  """

  use GenServer

  @table :eda_members
  @cache_name :members

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @doc """
  Gets a member in a guild.
  """
  @spec get(String.t() | integer(), String.t() | integer()) :: map() | nil
  def get(guild_id, user_id) do
    key = {to_string(guild_id), to_string(user_id)}

    case adapter().get(@table, key) do
      member when not is_nil(member) ->
        :telemetry.execute([:eda, :cache, :hit], %{count: 1}, %{cache: @cache_name})
        member

      nil ->
        :telemetry.execute([:eda, :cache, :miss], %{count: 1}, %{cache: @cache_name})
        nil
    end
  end

  @doc """
  Gets all members for a guild.
  """
  @spec for_guild(String.t() | integer()) :: [map()]
  def for_guild(guild_id) do
    guild_id = to_string(guild_id)

    adapter().match_prefix(@table, guild_id)
  end

  @doc """
  Creates or replaces a member in the cache.
  """
  @spec create(String.t(), map()) :: map()
  def create(guild_id, member) do
    guild_id = to_string(guild_id)
    user_id = to_string(member["user"]["id"])
    key = {guild_id, user_id}
    member_with_guild = Map.put(member, "guild_id", guild_id)

    case EDA.Cache.Policy.check(
           EDA.Cache.Config.policy(@cache_name),
           :member,
           key,
           member_with_guild
         ) do
      :cache ->
        adapter().put(@table, key, member_with_guild)
        EDA.Cache.Evictor.touch(@table, key)
        :telemetry.execute([:eda, :cache, :write], %{count: 1}, %{cache: @cache_name})
        member_with_guild

      :skip ->
        :telemetry.execute([:eda, :cache, :skip], %{count: 1}, %{cache: @cache_name})
        member_with_guild
    end
  end

  @doc """
  Updates a member in the cache (merges fields).
  """
  @spec update(String.t(), String.t(), map()) :: map() | nil
  def update(guild_id, user_id, updates) do
    key = {to_string(guild_id), to_string(user_id)}

    case adapter().get(@table, key) do
      existing when not is_nil(existing) ->
        updated = Map.merge(existing, updates)
        adapter().put(@table, key, updated)
        updated

      nil ->
        nil
    end
  end

  @doc """
  Removes a member from the cache.
  """
  @spec delete(String.t() | integer(), String.t() | integer()) :: :ok
  def delete(guild_id, user_id) do
    key = {to_string(guild_id), to_string(user_id)}
    adapter().delete(@table, key)
    EDA.Cache.Evictor.remove(@table, key)
    :ok
  end

  @doc """
  Removes all members for a guild.
  """
  @spec delete_guild(String.t() | integer()) :: :ok
  def delete_guild(guild_id) do
    guild_id = to_string(guild_id)
    adapter().delete_prefix(@table, guild_id)
    :ok
  end

  @doc """
  Returns the number of members for a guild.
  """
  @spec count_for_guild(String.t() | integer()) :: non_neg_integer()
  def count_for_guild(guild_id) do
    guild_id |> for_guild() |> length()
  end

  @doc """
  Returns the total number of cached members.
  """
  @spec count() :: non_neg_integer()
  def count do
    adapter().count(@table)
  end

  @impl true
  def init(_opts) do
    :ok = adapter().init(@table, [])
    {:ok, %{table: @table}}
  end

  defp adapter, do: EDA.Cache.Adapter.current()
end
