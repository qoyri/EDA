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
  Gets the current bot user.
  """
  @spec me() :: map() | nil
  def me do
    case :persistent_term.get(@me_key, nil) do
      nil -> nil
      user -> user
    end
  end

  @doc """
  Stores the current bot user.
  """
  @spec put_me(map()) :: :ok
  def put_me(user) do
    :persistent_term.put(@me_key, user)
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
end
