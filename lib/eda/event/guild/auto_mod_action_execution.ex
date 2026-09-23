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
  def from_raw(%__MODULE__{} = parsed), do: parsed

  def from_raw(raw) when is_map(raw) do
    action =
      case :maps.get("action", raw, nil) do
        map when is_map(map) -> EDA.AutoMod.Action.from_raw(map)
        _ -> nil
      end

    %__MODULE__{
      guild_id: :maps.get("guild_id", raw, nil),
      action: action,
      rule_id: :maps.get("rule_id", raw, nil),
      rule_trigger_type:
        EDA.Enum.name(EDA.AutoMod.trigger_types(), :maps.get("rule_trigger_type", raw, nil)),
      user_id: :maps.get("user_id", raw, nil),
      channel_id: :maps.get("channel_id", raw, nil),
      message_id: :maps.get("message_id", raw, nil),
      alert_system_message_id: :maps.get("alert_system_message_id", raw, nil),
      content: :maps.get("content", raw, nil),
      matched_keyword: :maps.get("matched_keyword", raw, nil),
      matched_content: :maps.get("matched_content", raw, nil)
    }
  end
end
