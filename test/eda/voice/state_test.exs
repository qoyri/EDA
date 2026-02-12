defmodule EDA.Voice.StateTest do
  use ExUnit.Case, async: true

  alias EDA.Voice.State

  describe "struct" do
    test "creates with defaults" do
      state = %State{}

      assert state.guild_id == nil
      assert state.channel_id == nil
      assert state.session_id == nil
      assert state.token == nil
      assert state.endpoint == nil
      assert state.ssrc == nil
      assert state.secret_key == nil
      assert state.ip == nil
      assert state.port == nil
      assert state.udp_socket == nil
      assert state.encryption_mode == nil
      assert state.session_pid == nil
      assert state.audio_pid == nil
      assert state.sequence == 0
      assert state.timestamp == 0
      assert state.speaking == false
      assert state.paused == false
      assert state.ready == false
      assert state.nonce == 0
    end

    test "creates with specified fields" do
      state = %State{
        guild_id: "123",
        channel_id: "456",
        session_id: "sess_abc",
        ready: true,
        sequence: 100,
        timestamp: 48_000
      }

      assert state.guild_id == "123"
      assert state.channel_id == "456"
      assert state.session_id == "sess_abc"
      assert state.ready == true
      assert state.sequence == 100
      assert state.timestamp == 48_000
    end

    test "can update fields" do
      state = %State{guild_id: "123", ready: false}
      updated = %{state | ready: true, ssrc: 42}

      assert updated.ready == true
      assert updated.ssrc == 42
      assert updated.guild_id == "123"
    end
  end
end
