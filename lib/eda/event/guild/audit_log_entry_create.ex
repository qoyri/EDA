defmodule EDA.Event.GuildAuditLogEntryCreate do
  @moduledoc """
  Sent when an audit log entry is created. Requires the `GUILD_MODERATION` intent. Delivers an
  `EDA.AuditLog.Entry` with its `guild_id`, not a struct of its own.

  The consumer receives `{:GUILD_AUDIT_LOG_ENTRY_CREATE, %EDA.AuditLog.Entry{}}`. This module only
  parses the payload.
  """

  @doc "Parses the `GUILD_AUDIT_LOG_ENTRY_CREATE` payload into an `EDA.AuditLog.Entry`."
  @spec from_raw(map()) :: EDA.AuditLog.Entry.t()
  def from_raw(raw) when is_map(raw), do: EDA.AuditLog.Entry.from_raw(raw)
end
