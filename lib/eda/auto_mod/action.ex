defmodule EDA.AutoMod.Action do
  @moduledoc """
  Represents an action taken by an Auto Moderation rule.

  ## Action Types

  | Value | Name | Description |
  |-------|------|-------------|
  | 1 | `block_message` | Block the message with optional custom response |
  | 2 | `send_alert` | Send alert to a specified channel |
  | 3 | `timeout` | Timeout the user (max 4 weeks) |
  | 4 | `block_member_interaction` | Block member interactions in the guild |

  ## Helper Constructors

      EDA.AutoMod.Action.block_message()
      EDA.AutoMod.Action.block_message("Custom blocked message")
      EDA.AutoMod.Action.send_alert("channel_id")
      EDA.AutoMod.Action.timeout(60)
      EDA.AutoMod.Action.block_member_interaction()
  """

  alias EDA.AutoMod.ActionMetadata

  use EDA.Event.Access

  @types %{
    1 => :block_message,
    2 => :send_alert_message,
    3 => :timeout,
    4 => :block_member_interaction
  }

  defstruct [:type, :metadata]

  @type t :: %__MODULE__{
          type:
            :block_message
            | :send_alert_message
            | :timeout
            | :block_member_interaction
            | integer()
            | nil,
          metadata: ActionMetadata.t() | nil
        }

  @doc "Converts a raw Discord action map into this struct."
  @spec from_raw(map()) :: t()
  def from_raw(%__MODULE__{} = parsed), do: parsed

  def from_raw(raw) when is_map(raw) do
    %__MODULE__{
      type: EDA.Enum.name(@types, :maps.get("type", raw, nil)),
      metadata: ActionMetadata.from_raw(:maps.get("metadata", raw, nil))
    }
  end

  @doc "Converts this struct to a map for API serialization."
  @spec to_map(t()) :: map()
  def to_map(%__MODULE__{} = action) do
    map = %{type: type_value(action.type)}

    if action.metadata do
      Map.put(map, :metadata, ActionMetadata.to_map(action.metadata))
    else
      map
    end
  end

  # ── Helper Constructors ──

  @doc "Creates a block_message action (type 1) with no custom message."
  @spec block_message() :: t()
  def block_message, do: %__MODULE__{type: :block_message, metadata: nil}

  @doc "Creates a block_message action (type 1) with a custom response message."
  @spec block_message(String.t()) :: t()
  def block_message(custom_message) when is_binary(custom_message) do
    %__MODULE__{type: :block_message, metadata: %ActionMetadata{custom_message: custom_message}}
  end

  @doc "Creates a send_alert action (type 2) targeting the given channel."
  @spec send_alert(String.t()) :: t()
  def send_alert(channel_id) when is_binary(channel_id) do
    %__MODULE__{type: :send_alert_message, metadata: %ActionMetadata{channel_id: channel_id}}
  end

  @doc "Creates a timeout action (type 3) with the given duration in seconds."
  @spec timeout(integer()) :: t()
  def timeout(duration_seconds) when is_integer(duration_seconds) do
    %__MODULE__{type: :timeout, metadata: %ActionMetadata{duration_seconds: duration_seconds}}
  end

  @doc "Creates a block_member_interaction action (type 4)."
  @spec block_member_interaction() :: t()
  def block_member_interaction, do: %__MODULE__{type: :block_member_interaction, metadata: nil}

  @doc """
  The integer Discord uses for an action type, from its atom or the integer itself.
  """
  @spec type_value(atom() | integer()) :: integer()
  def type_value(value), do: EDA.Enum.value!(@types, value, "AutoMod action type")
end
