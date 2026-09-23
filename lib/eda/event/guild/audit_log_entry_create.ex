defmodule EDA.Event.GuildAuditLogEntryCreate do
  @moduledoc "Dispatched when a guild audit log entry is created. Requires `GUILD_MODERATION` intent."
  use EDA.Event.Access

  defstruct [:id, :target_id, :user_id, :action_type, :changes, :reason, :options, :guild_id]

  @type t :: %__MODULE__{
          id: String.t() | nil,
          target_id: String.t() | nil,
          user_id: String.t() | nil,
          action_type: atom() | integer() | nil,
          changes: [EDA.AuditLog.Change.t()] | nil,
          reason: String.t() | nil,
          options: map() | nil,
          guild_id: String.t() | nil
        }

  @doc "Converts a raw Discord payload into this event struct."
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
      options: raw["options"],
      guild_id: raw["guild_id"]
    }
  end
end
