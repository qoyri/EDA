defmodule EDA.Event.GuildAuditLogEntryCreateTest do
  use ExUnit.Case, async: true

  alias EDA.Event.GuildAuditLogEntryCreate
  alias EDA.AuditLog.Change

  describe "from_raw/1" do
    test "parses all fields including guild_id" do
      raw = %{
        "id" => "entry1",
        "target_id" => "user1",
        "user_id" => "mod1",
        "action_type" => 22,
        "reason" => "rule violation",
        "options" => %{},
        "guild_id" => "guild1",
        "changes" => [
          %{"key" => "nick", "old_value" => "old", "new_value" => "new"}
        ]
      }

      event = GuildAuditLogEntryCreate.from_raw(raw)

      assert %GuildAuditLogEntryCreate{} = event
      assert event.id == "entry1"
      assert event.guild_id == "guild1"
      assert event.action_type == :member_ban_add
      assert event.reason == "rule violation"
      assert [%Change{key: "nick"}] = event.changes
    end

    test "handles nil changes" do
      raw = %{"id" => "entry1", "guild_id" => "guild1", "action_type" => 20}
      event = GuildAuditLogEntryCreate.from_raw(raw)
      assert event.changes == nil
    end
  end

  describe "Event.from_raw/2 integration" do
    test "GUILD_AUDIT_LOG_ENTRY_CREATE routes correctly" do
      raw = %{"id" => "e1", "guild_id" => "g1", "action_type" => 22}
      result = EDA.Event.from_raw("GUILD_AUDIT_LOG_ENTRY_CREATE", raw)
      assert %GuildAuditLogEntryCreate{} = result
      assert result.id == "e1"
    end
  end
end
