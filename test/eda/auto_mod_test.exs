defmodule EDA.AutoModTest do
  use ExUnit.Case, async: true

  alias EDA.AutoMod
  alias EDA.AutoMod.{Action, ActionMetadata, TriggerMetadata}

  # ── Constants ──────────────────────────────────────────────────────

  describe "constants" do
    test "event types" do
      assert AutoMod.event_message_send() == 1
      assert AutoMod.event_member_update() == 2
    end

    test "trigger types" do
      assert AutoMod.trigger_keyword() == 1
      assert AutoMod.trigger_spam() == 3
      assert AutoMod.trigger_keyword_preset() == 4
      assert AutoMod.trigger_mention_spam() == 5
      assert AutoMod.trigger_member_profile() == 6
    end

    test "action types" do
      assert AutoMod.action_block_message() == 1
      assert AutoMod.action_send_alert() == 2
      assert AutoMod.action_timeout() == 3
      assert AutoMod.action_block_member_interaction() == 4
    end

    test "presets" do
      assert AutoMod.preset_profanity() == 1
      assert AutoMod.preset_sexual_content() == 2
      assert AutoMod.preset_slurs() == 3
    end

    test "limits" do
      assert AutoMod.max_keyword_amount() == 1000
      assert AutoMod.max_keyword_length() == 60
      assert AutoMod.max_regex_patterns() == 10
      assert AutoMod.max_regex_length() == 260
      assert AutoMod.max_allow_list_keyword() == 100
      assert AutoMod.max_allow_list_preset() == 1000
      assert AutoMod.max_mention_limit() == 50
      assert AutoMod.max_exempt_roles() == 20
      assert AutoMod.max_exempt_channels() == 50
      assert AutoMod.max_custom_message_length() == 150
      assert AutoMod.max_timeout_seconds() == 2_419_200
      assert AutoMod.max_name_length() == 100
    end
  end

  # ── from_raw/1 ─────────────────────────────────────────────────────

  describe "from_raw/1" do
    test "parses a complete rule with nested structs" do
      raw = %{
        "id" => "r1",
        "guild_id" => "g1",
        "name" => "Block bad words",
        "creator_id" => "u1",
        "event_type" => 1,
        "trigger_type" => 1,
        "trigger_metadata" => %{
          "keyword_filter" => ["badword"],
          "regex_patterns" => ["b[a4]d.*"],
          "allow_list" => ["badge"]
        },
        "actions" => [
          %{"type" => 1, "metadata" => %{"custom_message" => "Blocked!"}},
          %{"type" => 2, "metadata" => %{"channel_id" => "c1"}}
        ],
        "enabled" => true,
        "exempt_roles" => ["role1"],
        "exempt_channels" => ["chan1"]
      }

      rule = AutoMod.from_raw(raw)
      assert %AutoMod{} = rule
      assert rule.id == "r1"
      assert rule.guild_id == "g1"
      assert rule.name == "Block bad words"
      assert rule.creator_id == "u1"
      assert rule.event_type == :message_send
      assert rule.trigger_type == :keyword
      assert rule.enabled == true
      assert rule.exempt_roles == ["role1"]
      assert rule.exempt_channels == ["chan1"]

      # Nested TriggerMetadata
      assert %TriggerMetadata{} = rule.trigger_metadata
      assert rule.trigger_metadata.keyword_filter == ["badword"]
      assert rule.trigger_metadata.regex_patterns == ["b[a4]d.*"]
      assert rule.trigger_metadata.allow_list == ["badge"]

      # Nested Actions
      assert [%Action{type: :block_message}, %Action{type: :send_alert_message}] = rule.actions
      assert %ActionMetadata{custom_message: "Blocked!"} = hd(rule.actions).metadata
      assert %ActionMetadata{channel_id: "c1"} = List.last(rule.actions).metadata
    end

    test "handles missing optional fields" do
      rule = AutoMod.from_raw(%{"id" => "r1"})
      assert rule.id == "r1"
      assert rule.trigger_metadata == nil
      assert rule.actions == nil
      assert rule.exempt_roles == nil
    end

    test "handles mention spam trigger metadata" do
      raw = %{
        "trigger_metadata" => %{
          "mention_total_limit" => 5,
          "mention_raid_protection_enabled" => true
        }
      }

      rule = AutoMod.from_raw(raw)
      assert rule.trigger_metadata.mention_total_limit == 5
      assert rule.trigger_metadata.mention_raid_protection_enabled == true
    end

    test "handles keyword preset trigger metadata" do
      raw = %{
        "trigger_metadata" => %{
          "presets" => [1, 2, 3],
          "allow_list" => ["allowed"]
        }
      }

      rule = AutoMod.from_raw(raw)
      assert rule.trigger_metadata.presets == [:profanity, :sexual_content, :slurs]
      assert rule.trigger_metadata.allow_list == ["allowed"]
    end
  end

  # ── TriggerMetadata ────────────────────────────────────────────────

  describe "TriggerMetadata" do
    test "from_raw/1 returns nil for nil" do
      assert TriggerMetadata.from_raw(nil) == nil
    end

    test "to_map/1 drops nil values" do
      meta = %TriggerMetadata{keyword_filter: ["test"], regex_patterns: nil}
      map = TriggerMetadata.to_map(meta)
      assert map == %{keyword_filter: ["test"]}
      refute Map.has_key?(map, :regex_patterns)
    end
  end

  # ── ActionMetadata ─────────────────────────────────────────────────

  describe "ActionMetadata" do
    test "from_raw/1 returns nil for nil" do
      assert ActionMetadata.from_raw(nil) == nil
    end

    test "from_raw/1 parses all fields" do
      raw = %{
        "channel_id" => "c1",
        "duration_seconds" => 60,
        "custom_message" => "Nope"
      }

      meta = ActionMetadata.from_raw(raw)
      assert meta.channel_id == "c1"
      assert meta.duration_seconds == 60
      assert meta.custom_message == "Nope"
    end

    test "to_map/1 drops nil values" do
      meta = %ActionMetadata{channel_id: "c1"}
      map = ActionMetadata.to_map(meta)
      assert map == %{channel_id: "c1"}
    end
  end

  # ── Action helpers ─────────────────────────────────────────────────

  describe "Action helpers" do
    test "block_message/0 creates type 1 with no metadata" do
      action = Action.block_message()
      assert action.type == :block_message
      assert action.metadata == nil
    end

    test "block_message/1 creates type 1 with custom message" do
      action = Action.block_message("Not allowed")
      assert action.type == :block_message
      assert action.metadata.custom_message == "Not allowed"
    end

    test "send_alert/1 creates type 2 with channel_id" do
      action = Action.send_alert("c1")
      assert action.type == :send_alert_message
      assert action.metadata.channel_id == "c1"
    end

    test "timeout/1 creates type 3 with duration" do
      action = Action.timeout(60)
      assert action.type == :timeout
      assert action.metadata.duration_seconds == 60
    end

    test "block_member_interaction/0 creates type 4 with no metadata" do
      action = Action.block_member_interaction()
      assert action.type == :block_member_interaction
      assert action.metadata == nil
    end
  end

  # ── Action to_map/1 ────────────────────────────────────────────────

  describe "Action.to_map/1" do
    test "serializes action without metadata" do
      assert Action.to_map(Action.block_message()) == %{type: 1}
    end

    test "serializes action with metadata" do
      map = Action.to_map(Action.send_alert("c1"))
      assert map == %{type: 2, metadata: %{channel_id: "c1"}}
    end

    test "serializes timeout action" do
      map = Action.to_map(Action.timeout(300))
      assert map == %{type: 3, metadata: %{duration_seconds: 300}}
    end
  end
end
