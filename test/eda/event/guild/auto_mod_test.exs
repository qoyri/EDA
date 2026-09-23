defmodule EDA.Event.AutoModTest do
  use ExUnit.Case, async: true

  alias EDA.Event

  alias EDA.Event.{
    AutoModRuleCreate,
    AutoModRuleUpdate,
    AutoModRuleDelete,
    AutoModActionExecution
  }

  alias EDA.AutoMod
  alias EDA.AutoMod.Action

  @rule_raw %{
    "id" => "r1",
    "guild_id" => "g1",
    "name" => "Block spam",
    "creator_id" => "u1",
    "event_type" => 1,
    "trigger_type" => 1,
    "trigger_metadata" => %{"keyword_filter" => ["spam"]},
    "actions" => [%{"type" => 1, "metadata" => %{"custom_message" => "No spam"}}],
    "enabled" => true,
    "exempt_roles" => [],
    "exempt_channels" => []
  }

  # ── AutoModRuleCreate ──────────────────────────────────────────────

  describe "AutoModRuleCreate.from_raw/1" do
    test "wraps raw payload as AutoMod struct" do
      event = AutoModRuleCreate.from_raw(@rule_raw)
      assert %AutoModRuleCreate{} = event
      assert %AutoMod{id: "r1", name: "Block spam"} = event.rule
      assert event.rule.trigger_metadata.keyword_filter == ["spam"]
    end
  end

  # ── AutoModRuleUpdate ──────────────────────────────────────────────

  describe "AutoModRuleUpdate.from_raw/1" do
    test "wraps raw payload as AutoMod struct" do
      event = AutoModRuleUpdate.from_raw(@rule_raw)
      assert %AutoModRuleUpdate{} = event
      assert %AutoMod{id: "r1"} = event.rule
    end
  end

  # ── AutoModRuleDelete ──────────────────────────────────────────────

  describe "AutoModRuleDelete.from_raw/1" do
    test "wraps raw payload as AutoMod struct" do
      event = AutoModRuleDelete.from_raw(@rule_raw)
      assert %AutoModRuleDelete{} = event
      assert %AutoMod{id: "r1"} = event.rule
    end
  end

  # ── AutoModActionExecution ─────────────────────────────────────────

  describe "AutoModActionExecution.from_raw/1" do
    test "parses all execution fields" do
      raw = %{
        "guild_id" => "g1",
        "action" => %{"type" => 1, "metadata" => %{"custom_message" => "Blocked"}},
        "rule_id" => "r1",
        "rule_trigger_type" => 1,
        "user_id" => "u1",
        "channel_id" => "c1",
        "message_id" => "m1",
        "alert_system_message_id" => "a1",
        "content" => "bad message",
        "matched_keyword" => "bad",
        "matched_content" => "bad"
      }

      event = AutoModActionExecution.from_raw(raw)
      assert %AutoModActionExecution{} = event
      assert event.guild_id == "g1"
      assert event.rule_id == "r1"
      assert event.rule_trigger_type == :keyword
      assert event.user_id == "u1"
      assert event.channel_id == "c1"
      assert event.message_id == "m1"
      assert event.alert_system_message_id == "a1"
      assert event.content == "bad message"
      assert event.matched_keyword == "bad"
      assert event.matched_content == "bad"
      assert %Action{type: :block_message} = event.action
      assert event.action.metadata.custom_message == "Blocked"
    end

    test "handles nil action" do
      event = AutoModActionExecution.from_raw(%{"guild_id" => "g1"})
      assert event.action == nil
    end
  end

  # ── Event routing ──────────────────────────────────────────────────

  describe "Event.from_raw/2 routing" do
    test "AUTO_MODERATION_RULE_CREATE" do
      result = Event.from_raw("AUTO_MODERATION_RULE_CREATE", @rule_raw)
      assert %AutoModRuleCreate{} = result
    end

    test "AUTO_MODERATION_RULE_UPDATE" do
      result = Event.from_raw("AUTO_MODERATION_RULE_UPDATE", @rule_raw)
      assert %AutoModRuleUpdate{} = result
    end

    test "AUTO_MODERATION_RULE_DELETE" do
      result = Event.from_raw("AUTO_MODERATION_RULE_DELETE", @rule_raw)
      assert %AutoModRuleDelete{} = result
    end

    test "AUTO_MODERATION_ACTION_EXECUTION" do
      raw = %{
        "guild_id" => "g1",
        "action" => %{"type" => 1},
        "rule_id" => "r1",
        "rule_trigger_type" => 1,
        "user_id" => "u1"
      }

      result = Event.from_raw("AUTO_MODERATION_ACTION_EXECUTION", raw)
      assert %AutoModActionExecution{} = result
      assert result.guild_id == "g1"
    end
  end
end
