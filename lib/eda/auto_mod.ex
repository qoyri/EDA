defmodule EDA.AutoMod do
  @moduledoc """
  Represents a Discord Auto Moderation rule.

  Auto Moderation allows guilds to automatically filter messages and member
  profiles based on keywords, spam detection, mention limits, and Discord's
  preset word lists.

  ## Trigger Types

  | Value | Name | Max per Guild | Description |
  |-------|------|---------------|-------------|
  | 1 | `keyword` | 6 | Custom keyword filter |
  | 3 | `spam` | 1 | Discord's spam detection |
  | 4 | `keyword_preset` | 1 | Discord's preset word lists |
  | 5 | `mention_spam` | 1 | Unique mention threshold |
  | 6 | `member_profile` | 1 | Profile keyword filter |

  ## Constants

  All Discord limits are exposed as functions:

      EDA.AutoMod.trigger_keyword()        # => 1
      EDA.AutoMod.max_keyword_amount()     # => 1000
      EDA.AutoMod.max_exempt_roles()       # => 20
  """

  alias EDA.AutoMod.{Action, TriggerMetadata}

  use EDA.Event.Access

  @event_types %{1 => :message_send, 2 => :member_update}
  @trigger_types %{
    1 => :keyword,
    3 => :spam,
    4 => :keyword_preset,
    5 => :mention_spam,
    6 => :member_profile
  }

  defstruct [
    :id,
    :guild_id,
    :name,
    :creator_id,
    :event_type,
    :trigger_type,
    :trigger_metadata,
    :actions,
    :enabled,
    :exempt_roles,
    :exempt_channels
  ]

  @type t :: %__MODULE__{
          id: String.t() | nil,
          guild_id: String.t() | nil,
          name: String.t() | nil,
          creator_id: String.t() | nil,
          event_type: :message_send | :member_update | integer() | nil,
          trigger_type:
            :keyword | :spam | :keyword_preset | :mention_spam | :member_profile | integer() | nil,
          trigger_metadata: TriggerMetadata.t() | nil,
          actions: [Action.t()] | nil,
          enabled: boolean() | nil,
          exempt_roles: [String.t()] | nil,
          exempt_channels: [String.t()] | nil
        }

  # ── Event Types ──

  @doc "Message send event type (1)."
  @spec event_message_send() :: 1
  def event_message_send, do: 1

  @doc "Member update event type (2)."
  @spec event_member_update() :: 2
  def event_member_update, do: 2

  # ── Trigger Types ──

  @doc "Custom keyword filter trigger (1). Max 6 per guild."
  @spec trigger_keyword() :: 1
  def trigger_keyword, do: 1

  @doc "Discord spam detection trigger (3). Max 1 per guild."
  @spec trigger_spam() :: 3
  def trigger_spam, do: 3

  @doc "Discord preset word lists trigger (4). Max 1 per guild."
  @spec trigger_keyword_preset() :: 4
  def trigger_keyword_preset, do: 4

  @doc "Unique mention threshold trigger (5). Max 1 per guild."
  @spec trigger_mention_spam() :: 5
  def trigger_mention_spam, do: 5

  @doc "Profile keyword filter trigger (6). Max 1 per guild."
  @spec trigger_member_profile() :: 6
  def trigger_member_profile, do: 6

  # ── Action Types ──

  @doc "Block message action type (1)."
  @spec action_block_message() :: 1
  def action_block_message, do: 1

  @doc "Send alert action type (2)."
  @spec action_send_alert() :: 2
  def action_send_alert, do: 2

  @doc "Timeout action type (3)."
  @spec action_timeout() :: 3
  def action_timeout, do: 3

  @doc "Block member interaction action type (4)."
  @spec action_block_member_interaction() :: 4
  def action_block_member_interaction, do: 4

  # ── Keyword Presets ──

  @doc "Profanity preset (1)."
  @spec preset_profanity() :: 1
  def preset_profanity, do: 1

  @doc "Sexual content preset (2)."
  @spec preset_sexual_content() :: 2
  def preset_sexual_content, do: 2

  @doc "Slurs preset (3)."
  @spec preset_slurs() :: 3
  def preset_slurs, do: 3

  # ── Limits ──

  @doc "Maximum number of keyword filter entries (1000)."
  @spec max_keyword_amount() :: 1000
  def max_keyword_amount, do: 1000

  @doc "Maximum keyword length in characters (60)."
  @spec max_keyword_length() :: 60
  def max_keyword_length, do: 60

  @doc "Maximum number of regex patterns (10)."
  @spec max_regex_patterns() :: 10
  def max_regex_patterns, do: 10

  @doc "Maximum regex pattern length in characters (260)."
  @spec max_regex_length() :: 260
  def max_regex_length, do: 260

  @doc "Maximum allow list entries for keyword trigger (100)."
  @spec max_allow_list_keyword() :: 100
  def max_allow_list_keyword, do: 100

  @doc "Maximum allow list entries for preset trigger (1000)."
  @spec max_allow_list_preset() :: 1000
  def max_allow_list_preset, do: 1000

  @doc "Maximum mention limit (50)."
  @spec max_mention_limit() :: 50
  def max_mention_limit, do: 50

  @doc "Maximum exempt roles per rule (20)."
  @spec max_exempt_roles() :: 20
  def max_exempt_roles, do: 20

  @doc "Maximum exempt channels per rule (50)."
  @spec max_exempt_channels() :: 50
  def max_exempt_channels, do: 50

  @doc "Maximum custom message length in characters (150)."
  @spec max_custom_message_length() :: 150
  def max_custom_message_length, do: 150

  @doc "Maximum timeout duration in seconds — 4 weeks (2,419,200)."
  @spec max_timeout_seconds() :: 2_419_200
  def max_timeout_seconds, do: 2_419_200

  @doc "Maximum rule name length in characters (100)."
  @spec max_name_length() :: 100
  def max_name_length, do: 100

  # ── Parsing ──

  @doc "Converts a raw Discord Auto Moderation rule map into this struct."
  @spec from_raw(map()) :: t()
  def from_raw(%__MODULE__{} = parsed), do: parsed

  def from_raw(raw) when is_map(raw) do
    actions =
      case :maps.get("actions", raw, nil) do
        list when is_list(list) -> Enum.map(list, &Action.from_raw/1)
        _ -> nil
      end

    %__MODULE__{
      id: :maps.get("id", raw, nil),
      guild_id: :maps.get("guild_id", raw, nil),
      name: :maps.get("name", raw, nil),
      creator_id: :maps.get("creator_id", raw, nil),
      event_type: EDA.Enum.name(@event_types, :maps.get("event_type", raw, nil)),
      trigger_type: EDA.Enum.name(@trigger_types, :maps.get("trigger_type", raw, nil)),
      trigger_metadata: TriggerMetadata.from_raw(:maps.get("trigger_metadata", raw, nil)),
      actions: actions,
      enabled: :maps.get("enabled", raw, nil),
      exempt_roles: :maps.get("exempt_roles", raw, nil),
      exempt_channels: :maps.get("exempt_channels", raw, nil)
    }
  end

  @doc """
  The integer Discord uses for an event type, from its atom (`:message_send`, `:member_update`)
  or the integer itself.
  """
  @spec event_type_value(atom() | integer() | nil) :: integer() | nil
  def event_type_value(value), do: EDA.Enum.value!(@event_types, value, "AutoMod event type")

  @doc """
  The integer Discord uses for a trigger type, from its atom (`:keyword`, `:spam`,
  `:keyword_preset`, `:mention_spam`, `:member_profile`) or the integer itself.
  """
  @spec trigger_type_value(atom() | integer() | nil) :: integer() | nil
  def trigger_type_value(value),
    do: EDA.Enum.value!(@trigger_types, value, "AutoMod trigger type")

  @doc false
  # The trigger names, for the execution event.
  def trigger_types, do: @trigger_types

  # ── Entity Manager ──

  use EDA.Entity

  @doc "Lists a guild's AutoMod rules."
  @spec list(String.t() | integer()) :: {:ok, [t()]} | {:error, term()}
  def list(guild_id), do: EDA.API.AutoMod.list(guild_id) |> parse_list()

  @doc """
  Fetches one AutoMod rule.

  Named `fetch_rule/2` rather than `fetch/2` because `Access.fetch/2` owns that arity.
  """
  @spec fetch_rule(String.t() | integer(), String.t() | integer()) ::
          {:ok, t()} | {:error, term()}
  def fetch_rule(guild_id, rule_id),
    do: EDA.API.AutoMod.get_rule(guild_id, rule_id) |> parse_response()

  @doc """
  Creates an AutoMod rule. Takes the parameters of `EDA.API.AutoMod.create/2`, with atoms for
  the enumerations and `EDA.AutoMod.Action` / `EDA.AutoMod.TriggerMetadata` structs if wanted.
  """
  @spec create(String.t() | integer(), map()) :: {:ok, t()} | {:error, term()}
  def create(guild_id, params), do: EDA.API.AutoMod.create(guild_id, params) |> parse_response()

  @doc "Modifies an AutoMod rule. Takes the parameters of `create/2`, all optional."
  @spec modify(String.t() | integer(), t() | String.t() | integer(), map()) ::
          {:ok, t()} | {:error, term()}
  def modify(guild_id, %__MODULE__{id: id}, params), do: modify(guild_id, id, params)

  def modify(guild_id, rule_id, params),
    do: EDA.API.AutoMod.modify(guild_id, rule_id, params) |> parse_response()

  @doc "Deletes an AutoMod rule."
  @spec delete(String.t() | integer(), t() | String.t() | integer()) :: :ok | {:error, term()}
  def delete(guild_id, %__MODULE__{id: id}), do: delete(guild_id, id)
  def delete(guild_id, rule_id), do: EDA.API.AutoMod.delete_rule(guild_id, rule_id)

  defp parse_list({:ok, list}) when is_list(list), do: {:ok, Enum.map(list, &from_raw/1)}
  defp parse_list({:error, _} = err), do: err
end
