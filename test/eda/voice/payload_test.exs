defmodule EDA.Voice.PayloadTest do
  use ExUnit.Case, async: true

  alias EDA.Voice.Payload

  describe "identify/4" do
    test "builds correct IDENTIFY payload" do
      payload = Payload.identify("guild_123", "user_456", "session_789", "token_abc")

      assert payload.op == 0
      assert payload.d.server_id == "guild_123"
      assert payload.d.user_id == "user_456"
      assert payload.d.session_id == "session_789"
      assert payload.d.token == "token_abc"
    end
  end

  describe "select_protocol/3" do
    test "builds correct SELECT_PROTOCOL payload" do
      payload = Payload.select_protocol("1.2.3.4", 12_345, "aead_aes256_gcm_rtpsize")

      assert payload.op == 1
      assert payload.d.protocol == "udp"
      assert payload.d.data.address == "1.2.3.4"
      assert payload.d.data.port == 12_345
      assert payload.d.data.mode == "aead_aes256_gcm_rtpsize"
    end
  end

  describe "heartbeat/2" do
    test "builds correct HEARTBEAT payload" do
      payload = Payload.heartbeat(42)

      assert payload.op == 3
      assert payload.d == %{t: 42, seq_ack: 0}
    end

    test "accepts large nonce values" do
      nonce = System.monotonic_time(:millisecond)
      payload = Payload.heartbeat(nonce, 5)

      assert payload.op == 3
      assert payload.d == %{t: nonce, seq_ack: 5}
    end
  end

  describe "speaking/2" do
    test "builds SPEAKING payload with speaking=true" do
      payload = Payload.speaking(12_345, true)

      assert payload.op == 5
      assert payload.d.speaking == 1
      assert payload.d.delay == 0
      assert payload.d.ssrc == 12_345
    end

    test "builds SPEAKING payload with speaking=false" do
      payload = Payload.speaking(12_345, false)

      assert payload.op == 5
      assert payload.d.speaking == 0
      assert payload.d.ssrc == 12_345
    end

    test "defaults to speaking=true" do
      payload = Payload.speaking(12_345)

      assert payload.d.speaking == 1
    end
  end

  describe "resume/3" do
    test "builds correct RESUME payload" do
      payload = Payload.resume("guild_123", "session_789", "token_abc")

      assert payload.op == 7
      assert payload.d.server_id == "guild_123"
      assert payload.d.session_id == "session_789"
      assert payload.d.token == "token_abc"
    end
  end

  describe "JSON encoding" do
    test "all payloads can be encoded to JSON" do
      payloads = [
        Payload.identify("g", "u", "s", "t"),
        Payload.select_protocol("1.2.3.4", 1234, "mode"),
        Payload.heartbeat(42),
        Payload.speaking(12_345),
        Payload.speaking(12_345, false),
        Payload.resume("g", "s", "t")
      ]

      for payload <- payloads do
        assert {:ok, json} = Jason.encode(payload)
        assert is_binary(json)
      end
    end
  end
end
