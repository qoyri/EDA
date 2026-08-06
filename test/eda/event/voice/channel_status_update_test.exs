defmodule EDA.Event.VoiceChannelStatusUpdateTest do
  use ExUnit.Case, async: true

  alias EDA.Event
  alias EDA.Event.VoiceChannelStatusUpdate

  describe "from_raw/1" do
    test "maps raw id -> channel_id, plus guild_id and status" do
      raw = %{"id" => "vc1", "guild_id" => "g1", "status" => "gaming"}

      event = VoiceChannelStatusUpdate.from_raw(raw)

      assert %VoiceChannelStatusUpdate{channel_id: "vc1", guild_id: "g1", status: "gaming"} =
               event
    end

    test "handles absent/nil status" do
      event = VoiceChannelStatusUpdate.from_raw(%{"id" => "vc1", "guild_id" => "g1"})

      assert event.channel_id == "vc1"
      assert event.status == nil
    end
  end

  describe "Event.from_raw/2 routing" do
    test "VOICE_CHANNEL_STATUS_UPDATE routes to VoiceChannelStatusUpdate" do
      data = %{"id" => "vc1", "guild_id" => "g1", "status" => "live"}

      result = Event.from_raw("VOICE_CHANNEL_STATUS_UPDATE", data)

      assert %VoiceChannelStatusUpdate{channel_id: "vc1", status: "live"} = result
    end
  end
end
