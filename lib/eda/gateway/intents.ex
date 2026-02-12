defmodule EDA.Gateway.Intents do
  @moduledoc """
  Discord Gateway Intents.

  Intents are used to control which events your bot receives from the Gateway.
  Some intents are "privileged" and require enabling in the Discord Developer Portal.

  ## Privileged Intents

  - `:guild_members` - Required to receive member-related events
  - `:guild_presences` - Required to receive presence updates
  - `:message_content` - Required to receive message content in guild messages

  ## Example

      config :eda,
        intents: [:guilds, :guild_messages, :message_content]

  Or use shortcuts:

      config :eda, intents: :all              # All intents
      config :eda, intents: :nonprivileged    # All non-privileged intents (default)
  """

  import Bitwise

  @intent_values %{
    guilds: 1 <<< 0,
    guild_members: 1 <<< 1,
    guild_moderation: 1 <<< 2,
    guild_expressions: 1 <<< 3,
    guild_integrations: 1 <<< 4,
    guild_webhooks: 1 <<< 5,
    guild_invites: 1 <<< 6,
    guild_voice_states: 1 <<< 7,
    guild_presences: 1 <<< 8,
    guild_messages: 1 <<< 9,
    guild_message_reactions: 1 <<< 10,
    guild_message_typing: 1 <<< 11,
    direct_messages: 1 <<< 12,
    direct_message_reactions: 1 <<< 13,
    direct_message_typing: 1 <<< 14,
    message_content: 1 <<< 15,
    guild_scheduled_events: 1 <<< 16,
    auto_moderation_configuration: 1 <<< 20,
    auto_moderation_execution: 1 <<< 21,
    guild_message_polls: 1 <<< 24,
    direct_message_polls: 1 <<< 25
  }

  @privileged_intents [:guild_members, :guild_presences, :message_content]

  @doc """
  Returns all available intent names.
  """
  @spec all_intents() :: [atom()]
  def all_intents, do: Map.keys(@intent_values)

  @doc """
  Returns privileged intent names.
  """
  @spec privileged_intents() :: [atom()]
  def privileged_intents, do: @privileged_intents

  @doc """
  Returns non-privileged intent names.
  """
  @spec nonprivileged_intents() :: [atom()]
  def nonprivileged_intents, do: all_intents() -- @privileged_intents

  @doc """
  Converts a list of intent atoms to a bitfield integer.

  ## Examples

      iex> EDA.Gateway.Intents.to_bitfield([:guilds, :guild_messages])
      513

      iex> EDA.Gateway.Intents.to_bitfield(:all)
      # Returns all intents combined

      iex> EDA.Gateway.Intents.to_bitfield(:nonprivileged)
      # Returns all non-privileged intents
  """
  @spec to_bitfield(atom() | [atom()]) :: integer()
  def to_bitfield(:all), do: to_bitfield(all_intents())
  def to_bitfield(:nonprivileged), do: to_bitfield(nonprivileged_intents())

  def to_bitfield(intents) when is_list(intents) do
    Enum.reduce(intents, 0, fn intent, acc ->
      case Map.get(@intent_values, intent) do
        nil -> raise ArgumentError, "Unknown intent: #{inspect(intent)}"
        value -> acc ||| value
      end
    end)
  end

  @doc """
  Checks if a specific intent is enabled in a bitfield.
  """
  @spec has_intent?(integer(), atom()) :: boolean()
  def has_intent?(bitfield, intent) do
    case Map.get(@intent_values, intent) do
      nil -> false
      value -> (bitfield &&& value) == value
    end
  end
end
