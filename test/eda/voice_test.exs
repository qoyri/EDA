defmodule EDA.VoiceTest do
  use ExUnit.Case

  # Voice processes are already started by the application supervisor

  describe "ready?/1" do
    test "returns false for unknown guild" do
      refute EDA.Voice.ready?("unknown_guild")
    end
  end

  describe "playing?/1" do
    test "returns false for unknown guild" do
      refute EDA.Voice.playing?("unknown_guild")
    end
  end

  describe "channel_id/1" do
    test "returns nil for unknown guild" do
      assert EDA.Voice.channel_id("unknown_guild") == nil
    end
  end

  describe "leave/1" do
    test "returns :ok for unknown guild" do
      assert EDA.Voice.leave("unknown_guild") == :ok
    end
  end

  describe "play/3" do
    test "returns error when not connected" do
      assert {:error, :not_connected} = EDA.Voice.play("unknown_guild", "test.mp3")
    end
  end

  describe "stop/1" do
    test "returns :ok for unknown guild" do
      assert EDA.Voice.stop("unknown_guild") == :ok
    end
  end

  describe "internal state management" do
    test "voice_state_update is a no-op for unknown guild" do
      EDA.Voice.voice_state_update("test_guild", "session_abc")
      refute EDA.Voice.ready?("test_guild")
    end

    test "voice_disconnected is a no-op for unknown guild" do
      EDA.Voice.voice_disconnected("unknown_guild")
    end

    test "playback_finished is a no-op for unknown guild" do
      EDA.Voice.playback_finished("unknown_guild")
    end
  end

  describe "listen/2" do
    test "returns empty list for unknown guild" do
      assert EDA.Voice.listen("unknown_guild", 10) == []
    end
  end
end
