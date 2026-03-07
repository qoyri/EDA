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

  describe "play/2, play/3 and play/4" do
    test "returns error when not connected" do
      assert {:error, :not_connected} = EDA.Voice.play("unknown_guild", "test.mp3")
    end

    test "accepts opts-only 3-arg calls when not connected" do
      assert {:error, :not_connected} =
               EDA.Voice.play("unknown_guild", "test.mp3", volume: 0.5)
    end

    test "accepts playback opts when not connected" do
      assert {:error, :not_connected} =
               EDA.Voice.play("unknown_guild", "test.mp3", :url, volume: 0.5)
    end
  end

  describe "play argument routing" do
    test "routes opts-only calls to default :url type" do
      guild_id = "play_opts_#{System.unique_integer([:positive])}"
      voice_pid = Process.whereis(EDA.Voice)

      assert {:ok, _} = Registry.register(EDA.Voice.Registry, {:session, guild_id}, :test)

      :sys.replace_state(EDA.Voice, fn state ->
        vs = %EDA.Voice.State{guild_id: guild_id, ready: true}
        %{state | guilds: Map.put(state.guilds, guild_id, vs)}
      end)

      :erlang.trace(voice_pid, true, [:call])
      :erlang.trace_pattern({EDA.Voice.Audio, :play, 5}, true, [:local])

      on_exit(fn ->
        :erlang.trace(voice_pid, false, [:call])
        :erlang.trace_pattern({EDA.Voice.Audio, :play, 5}, false, [:local])
        Registry.unregister(EDA.Voice.Registry, {:session, guild_id})

        :sys.replace_state(EDA.Voice, fn state ->
          %{state | guilds: Map.delete(state.guilds, guild_id)}
        end)
      end)

      assert :ok = EDA.Voice.play(guild_id, "test.mp3", volume: 0.5)

      assert_receive {:trace, ^voice_pid, :call,
                      {EDA.Voice.Audio, :play,
                       [^guild_id, "test.mp3", :url, %EDA.Voice.State{}, [volume: 0.5]]}},
                     1_000

      assert :ok = EDA.Voice.stop(guild_id)
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
      EDA.Voice.playback_finished("unknown_guild", 0, 0, 0)
    end
  end

  describe "listen/2" do
    test "returns empty list for unknown guild" do
      assert EDA.Voice.listen("unknown_guild", 10) == []
    end
  end
end
