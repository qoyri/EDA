defmodule EDA.Event.AutoModActionExecution do
  @moduledoc "Dispatched when an Auto Moderation rule action is executed."
  use EDA.Event.Access

  defstruct [
    :guild_id,
    :action,
    :rule_id,
    :rule_trigger_type,
    :user_id,
    :channel_id,
    :message_id,
    :alert_system_message_id,
    :content,
    :matched_keyword,
    :matched_content
  ]

  @type t :: %__MODULE__{
          guild_id: String.t() | nil,
          action: EDA.AutoMod.Action.t() | nil,
          rule_id: String.t() | nil,
          rule_trigger_type: atom() | integer() | nil,
          user_id: String.t() | nil,
          channel_id: String.t() | nil,
          message_id: String.t() | nil,
          alert_system_message_id: String.t() | nil,
          content: String.t() | nil,
          matched_keyword: String.t() | nil,
          matched_content: String.t() | nil
        }

  @doc "Converts a raw Discord payload into this event struct."
  @spec from_raw(map()) :: t()
  def from_raw(raw) when is_map(raw) do
    action =
      case raw["action"] do
        map when is_map(map) -> EDA.AutoMod.Action.from_raw(map)
        _ -> nil
      end

    %__MODULE__{
      guild_id: raw["guild_id"],
      action: action,
      rule_id: raw["rule_id"],
      rule_trigger_type: EDA.Enum.name(EDA.AutoMod.trigger_types(), raw["rule_trigger_type"]),
      user_id: raw["user_id"],
      channel_id: raw["channel_id"],
      message_id: raw["message_id"],
      alert_system_message_id: raw["alert_system_message_id"],
      content: raw["content"],
      matched_keyword: raw["matched_keyword"],
      matched_content: raw["matched_content"]
    }
  end
end
