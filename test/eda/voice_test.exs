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

  describe "another process of the same bot joining voice" do
    # Two processes on one token — a deploy overlapping the old instance — used to take the voice
    # connection from each other in a loop: 16 restarts each in 30 s, live. The update of the one
    # that joins carries its own gateway session id.
    @guild_id "7700000000000000555"

    setup do
      shard = EDA.Gateway.ShardManager.shard_for_guild(@guild_id)
      key = {EDA.Gateway.Connection, :session_id, shard}
      previous = :persistent_term.get(key, nil)
      :persistent_term.put(key, "our_session")

      :sys.replace_state(EDA.Voice, fn state ->
        vs = %EDA.Voice.State{
          guild_id: @guild_id,
          channel_id: "5",
          session_id: "our_session",
          ready: true
        }

        %{state | guilds: Map.put(state.guilds, @guild_id, vs)}
      end)

      on_exit(fn ->
        if previous, do: :persistent_term.put(key, previous), else: :persistent_term.erase(key)

        :sys.replace_state(EDA.Voice, fn state ->
          %{state | guilds: Map.delete(state.guilds, @guild_id)}
        end)
      end)
    end

    defp voice_guild do
      Map.get(:sys.get_state(EDA.Voice).guilds, @guild_id)
    end

    test "the process that joined last keeps the connection; this one lets go" do
      EDA.Voice.voice_state_update(@guild_id, "their_session", "5")
      assert voice_guild() == nil
      refute EDA.Voice.ready?(@guild_id)
    end

    test "an update carrying our own session is handled as before" do
      EDA.Voice.voice_state_update(@guild_id, "our_session", "5")
      assert %EDA.Voice.State{session_id: "our_session", channel_id: "5"} = voice_guild()
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
