defmodule EDA.Event.StageInstanceTest do
  use ExUnit.Case, async: true

  alias EDA.Event.{StageInstanceCreate, StageInstanceUpdate, StageInstanceDelete}

  @raw %{
    "id" => "stage1",
    "guild_id" => "guild1",
    "channel_id" => "channel1",
    "topic" => "Q&A Session",
    "privacy_level" => 2,
    "discoverable_disabled" => false,
    "guild_scheduled_event_id" => "event1"
  }

  describe "StageInstanceCreate" do
    test "parses all fields" do
      event = StageInstanceCreate.from_raw(@raw)

      assert %EDA.StageInstance{} = event
      assert event.id == "stage1"
      assert event.guild_id == "guild1"
      assert event.channel_id == "channel1"
      assert event.topic == "Q&A Session"
      assert event.privacy_level == :guild_only
      assert event.discoverable_disabled == false
      assert event.guild_scheduled_event_id == "event1"
    end

    test "routes via Event.from_raw/2" do
      result = EDA.Event.from_raw("STAGE_INSTANCE_CREATE", @raw)
      assert %EDA.StageInstance{} = result
    end
  end

  describe "StageInstanceUpdate" do
    test "parses all fields" do
      event = StageInstanceUpdate.from_raw(@raw)

      assert %EDA.StageInstance{} = event
      assert event.id == "stage1"
      assert event.topic == "Q&A Session"
    end

    test "routes via Event.from_raw/2" do
      result = EDA.Event.from_raw("STAGE_INSTANCE_UPDATE", @raw)
      assert %EDA.StageInstance{} = result
    end
  end

  describe "StageInstanceDelete" do
    test "parses all fields" do
      event = StageInstanceDelete.from_raw(@raw)

      assert %EDA.StageInstance{} = event
      assert event.id == "stage1"
      assert event.guild_id == "guild1"
    end

    test "routes via Event.from_raw/2" do
      result = EDA.Event.from_raw("STAGE_INSTANCE_DELETE", @raw)
      assert %EDA.StageInstance{} = result
    end
  end
end
