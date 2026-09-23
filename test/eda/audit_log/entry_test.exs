defmodule EDA.AuditLog.EntryTest do
  use ExUnit.Case, async: true

  alias EDA.AuditLog.{Entry, Change}

  describe "from_raw/1" do
    test "parses entry with changes" do
      raw = %{
        "id" => "123",
        "target_id" => "456",
        "user_id" => "789",
        "action_type" => 22,
        "reason" => "spamming",
        "options" => %{"count" => "1"},
        "changes" => [
          %{"key" => "name", "old_value" => "old", "new_value" => "new"}
        ]
      }

      entry = Entry.from_raw(raw)

      assert %Entry{} = entry
      assert entry.id == "123"
      assert entry.target_id == "456"
      assert entry.user_id == "789"
      assert entry.action_type == :member_ban_add
      assert entry.reason == "spamming"
      assert entry.options == %EDA.AuditLog.Entry.Options{count: 1}
      assert [%Change{key: "name"}] = entry.changes
    end

    test "handles nil changes" do
      raw = %{"id" => "123", "action_type" => 1}
      entry = Entry.from_raw(raw)

      assert entry.changes == nil
    end

    test "handles empty changes list" do
      raw = %{"id" => "123", "changes" => []}
      entry = Entry.from_raw(raw)

      assert entry.changes == []
    end

    test "supports Access protocol" do
      entry = Entry.from_raw(%{"id" => "123", "action_type" => 20})
      assert entry[:id] == "123"
      assert entry["action_type"] == :member_kick
    end
  end
end
