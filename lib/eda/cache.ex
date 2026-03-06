defmodule EDA.Cache do
  @moduledoc """
  Unified cache interface for EDA.

  This module provides a simple API for accessing cached Discord data.
  Data is automatically cached as events are received from the Gateway.

  ## Examples

      # Get a guild
      guild = EDA.Cache.get_guild("123456789")

      # Get a user
      user = EDA.Cache.get_user("987654321")

      # Get a channel
      channel = EDA.Cache.get_channel("111222333")

      # Get the bot user
      me = EDA.Cache.me()
  """

  @me_key :eda_current_user

  # Current User (Bot)

  @doc """
  Gets the current bot user as an `%EDA.User{}` struct.

  Returns `nil` if the bot hasn't connected yet.
  The raw map is also stored for internal callers that need string-key access.
  """
  @spec me() :: EDA.User.t() | map() | nil
  def me do
    :persistent_term.get(@me_key, nil)
  end

  @doc """
  Returns the raw map of the current bot user (string keys).

  Used internally by code that expects `me["id"]` string-key access
  (e.g., `app_id/0`, voice event routing).
  """
  @spec me_raw() :: map() | nil
  def me_raw do
    :persistent_term.get(:eda_current_user_raw, nil)
  end

  @doc """
  Stores the current bot user. Saves both the parsed `%EDA.User{}` struct
  and the raw map for backward compatibility.
  """
  @spec put_me(map()) :: :ok
  def put_me(user) when is_map(user) do
    :persistent_term.put(@me_key, EDA.User.from_raw(user))
    :persistent_term.put(:eda_current_user_raw, user)
    :ok
  end

  # Guilds

  @doc """
  Gets a guild by ID.
  """
  @spec get_guild(String.t() | integer()) :: map() | nil
  defdelegate get_guild(guild_id), to: EDA.Cache.Guild, as: :get

  @doc """
  Gets all cached guilds.
  """
  @spec guilds() :: [map()]
  defdelegate guilds(), to: EDA.Cache.Guild, as: :all

  @doc """
  Returns the number of cached guilds.
  """
  @spec guild_count() :: non_neg_integer()
  defdelegate guild_count(), to: EDA.Cache.Guild, as: :count

  # Users

  @doc """
  Gets a user by ID.
  """
  @spec get_user(String.t() | integer()) :: map() | nil
  defdelegate get_user(user_id), to: EDA.Cache.User, as: :get

  @doc """
  Gets all cached users.
  """
  @spec users() :: [map()]
  defdelegate users(), to: EDA.Cache.User, as: :all

  @doc """
  Returns the number of cached users.
  """
  @spec user_count() :: non_neg_integer()
  defdelegate user_count(), to: EDA.Cache.User, as: :count

  # Channels

  @doc """
  Gets a channel by ID.
  """
  @spec get_channel(String.t() | integer()) :: map() | nil
  defdelegate get_channel(channel_id), to: EDA.Cache.Channel, as: :get

  @doc """
  Gets all cached channels.
  """
  @spec channels() :: [map()]
  defdelegate channels(), to: EDA.Cache.Channel, as: :all

  @doc """
  Gets all channels for a guild.
  """
  @spec channels_for_guild(String.t() | integer()) :: [map()]
  defdelegate channels_for_guild(guild_id), to: EDA.Cache.Channel, as: :for_guild

  @doc """
  Returns the number of cached channels.
  """
  @spec channel_count() :: non_neg_integer()
  defdelegate channel_count(), to: EDA.Cache.Channel, as: :count

  # Members (guild-specific)

  @doc """
  Gets a member in a guild.
  """
  @spec get_member(String.t() | integer(), String.t() | integer()) :: map() | nil
  defdelegate get_member(guild_id, user_id), to: EDA.Cache.Member, as: :get

  @doc """
  Gets all members for a guild.
  """
  @spec members(String.t() | integer()) :: [map()]
  defdelegate members(guild_id), to: EDA.Cache.Member, as: :for_guild

  @doc """
  Returns the total number of cached members.
  """
  @spec member_count() :: non_neg_integer()
  defdelegate member_count(), to: EDA.Cache.Member, as: :count

  # Roles

  @doc """
  Gets a role by ID.
  """
  @spec get_role(String.t() | integer()) :: map() | nil
  defdelegate get_role(role_id), to: EDA.Cache.Role, as: :get

  @doc """
  Gets all roles for a guild.
  """
  @spec roles(String.t() | integer()) :: [map()]
  defdelegate roles(guild_id), to: EDA.Cache.Role, as: :for_guild

  @doc """
  Returns the total number of cached roles.
  """
  @spec role_count() :: non_neg_integer()
  defdelegate role_count(), to: EDA.Cache.Role, as: :count

  # Voice States

  @doc """
  Gets a user's voice state in a guild.
  """
  @spec get_voice_state(String.t() | integer(), String.t() | integer()) :: map() | nil
  defdelegate get_voice_state(guild_id, user_id), to: EDA.Cache.VoiceState, as: :get

  @doc """
  Gets all voice states for a guild.
  """
  @spec voice_states(String.t() | integer()) :: [map()]
  defdelegate voice_states(guild_id), to: EDA.Cache.VoiceState, as: :for_guild

  @doc """
  Gets all voice states for a specific channel in a guild.
  """
  @spec voice_channel_members(String.t() | integer(), String.t() | integer()) :: [map()]
  defdelegate voice_channel_members(guild_id, channel_id),
    to: EDA.Cache.VoiceState,
    as: :for_channel

  # Presences

  @doc """
  Gets a user's presence in a guild.
  """
  @spec get_presence(String.t() | integer(), String.t() | integer()) :: map() | nil
  defdelegate get_presence(guild_id, user_id), to: EDA.Cache.Presence, as: :get

  @doc """
  Gets all presences for a guild.
  """
  @spec presences(String.t() | integer()) :: [map()]
  defdelegate presences(guild_id), to: EDA.Cache.Presence, as: :for_guild

  # Fetch — cache-first with REST fallback

  @doc """
  Fetches a guild from cache, falling back to REST on miss.
  """
  @spec fetch_guild(String.t() | integer()) :: {:ok, map()} | {:error, term()}
  def fetch_guild(guild_id) do
    case get_guild(guild_id) do
      nil -> rest_fallback(:guilds, fn -> EDA.API.Guild.get(guild_id) end)
      guild -> {:ok, guild}
    end
  end

  @doc """
  Fetches a user from cache, falling back to REST on miss.
  """
  @spec fetch_user(String.t() | integer()) :: {:ok, map()} | {:error, term()}
  def fetch_user(user_id) do
    case get_user(user_id) do
      nil -> rest_fallback(:users, fn -> EDA.API.User.get(user_id) end)
      user -> {:ok, user}
    end
  end

  @doc """
  Fetches a channel from cache, falling back to REST on miss.
  """
  @spec fetch_channel(String.t() | integer()) :: {:ok, map()} | {:error, term()}
  def fetch_channel(channel_id) do
    case get_channel(channel_id) do
      nil -> rest_fallback(:channels, fn -> EDA.API.Channel.get(channel_id) end)
      channel -> {:ok, channel}
    end
  end

  @doc """
  Fetches a member from cache, falling back to REST on miss.
  """
  @spec fetch_member(String.t() | integer(), String.t() | integer()) ::
          {:ok, map()} | {:error, term()}
  def fetch_member(guild_id, user_id) do
    case get_member(guild_id, user_id) do
      nil ->
        rest_fallback(:members, fn -> EDA.API.Member.get(guild_id, user_id) end)

      member ->
        {:ok, member}
    end
  end

  @doc """
  Fetches a role from cache, falling back to REST on miss.

  Note: the REST API returns all roles for the guild, so `guild_id` is required.
  """
  @spec fetch_role(String.t() | integer(), String.t() | integer()) ::
          {:ok, map()} | {:error, term()}
  def fetch_role(guild_id, role_id) do
    case get_role(role_id) do
      nil -> fetch_role_from_rest(guild_id, role_id)
      role -> {:ok, role}
    end
  end

  defp fetch_role_from_rest(guild_id, role_id) do
    role_id_str = to_string(role_id)

    with {:ok, roles} <- EDA.API.Role.list(guild_id) do
      :telemetry.execute([:eda, :cache, :fallback], %{count: 1}, %{cache: :roles})
      cache_roles_if_allowed(guild_id, roles)
      find_role(roles, role_id_str)
    end
  end

  defp cache_roles_if_allowed(guild_id, roles) do
    case EDA.Cache.Policy.check(EDA.Cache.Config.policy(:roles), :role, nil, nil) do
      :cache -> Enum.each(roles, &EDA.Cache.Role.create(to_string(guild_id), &1))
      :skip -> :ok
    end
  end

  defp find_role(roles, role_id_str) do
    case Enum.find(roles, fn r -> to_string(r["id"]) == role_id_str end) do
      nil -> {:error, :not_found}
      role -> {:ok, role}
    end
  end

  defp rest_fallback(cache_name, rest_fn) do
    case rest_fn.() do
      {:ok, data} ->
        :telemetry.execute([:eda, :cache, :fallback], %{count: 1}, %{cache: cache_name})
        maybe_cache(cache_name, data)
        {:ok, data}

      {:error, _} = error ->
        error
    end
  end

  defp maybe_cache(cache_name, data) do
    case EDA.Cache.Policy.check(EDA.Cache.Config.policy(cache_name), nil, nil, data) do
      :cache -> do_cache(cache_name, data)
      :skip -> :ok
    end
  end

  defp do_cache(:guilds, data), do: EDA.Cache.Guild.create(data)
  defp do_cache(:users, data), do: EDA.Cache.User.create(data)
  defp do_cache(:channels, data), do: EDA.Cache.Channel.create(data)

  defp do_cache(:members, data) do
    if guild_id = data["guild_id"] do
      EDA.Cache.Member.create(guild_id, data)
    end
  end

  defp do_cache(_, _data), do: :ok
end
