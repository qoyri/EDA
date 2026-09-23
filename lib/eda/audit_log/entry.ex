defmodule EDA.AuditLog.Entry do
  @moduledoc """
  A single audit log entry, from `EDA.API.AuditLog` or the `GUILD_AUDIT_LOG_ENTRY_CREATE`
  event, which adds its `guild_id`.

  `changes` are `EDA.AuditLog.Change` structs, `options` an `EDA.AuditLog.Entry.Options`.
  """
  use EDA.Event.Access

  defstruct [:id, :guild_id, :target_id, :user_id, :action_type, :changes, :reason, :options]

  @type t :: %__MODULE__{
          id: String.t() | nil,
          guild_id: String.t() | nil,
          target_id: String.t() | nil,
          user_id: String.t() | nil,
          action_type: atom() | integer() | nil,
          changes: [EDA.AuditLog.Change.t()] | nil,
          reason: String.t() | nil,
          options: EDA.AuditLog.Entry.Options.t() | nil
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
      guild_id: raw["guild_id"],
      target_id: raw["target_id"],
      user_id: raw["user_id"],
      action_type: EDA.Enum.name(EDA.AuditLog.action_types(), raw["action_type"]),
      changes: changes,
      reason: raw["reason"],
      options: EDA.AuditLog.Entry.Options.from_raw(raw["options"])
    }
  end
end
