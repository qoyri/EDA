defmodule EDA.AuditLog.Entry do
  @moduledoc "A single audit log entry."
  use EDA.Event.Access

  defstruct [:id, :target_id, :user_id, :action_type, :changes, :reason, :options]

  @type t :: %__MODULE__{
          id: String.t() | nil,
          target_id: String.t() | nil,
          user_id: String.t() | nil,
          action_type: atom() | integer() | nil,
          changes: [EDA.AuditLog.Change.t()] | nil,
          reason: String.t() | nil,
          options: map() | nil
        }

  @doc "Converts a raw audit log entry map into this struct. Parses changes into Change structs."
  @spec from_raw(map()) :: t()
  def from_raw(raw) when is_map(raw) do
    changes =
      case raw["changes"] do
        nil -> nil
        list when is_list(list) -> Enum.map(list, &EDA.AuditLog.Change.from_raw/1)
      end

    %__MODULE__{
      id: raw["id"],
      target_id: raw["target_id"],
      user_id: raw["user_id"],
      action_type: EDA.Enum.name(EDA.AuditLog.action_types(), raw["action_type"]),
      changes: changes,
      reason: raw["reason"],
      options: raw["options"]
    }
  end
end
