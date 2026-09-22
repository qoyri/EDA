defmodule EDA.Voice.SessionReceiveTest do
  @moduledoc """
  What the voice session dispatches as `VOICE_AUDIO` from the packets it receives.

  Besides audio, a client sends RTP packets that carry only padding — bandwidth probes, with the
  timestamp of the frame before them. Seen live on 2026-09-22: 10 in 40 s of speech, every one
  of them the whole of the DAVE decryption failures.
  """

  # NOT async — the consumer is global Application env.
  use ExUnit.Case

  alias EDA.Voice.{Crypto, Session}

  defmodule Consumer do
    def handle_event({:VOICE_AUDIO, audio}), do: send(:session_receive_test, {:audio, audio})
    def handle_event(_), do: :ok
  end

  @key :crypto.strong_rand_bytes(32)
  @mode "aead_aes256_gcm_rtpsize"
  @ssrc 4242

  setup do
    Process.register(self(), :session_receive_test)
    Application.put_env(:eda, :consumer, Consumer)
    on_exit(fn -> Application.delete_env(:eda, :consumer) end)

    state = %Session{
      guild_id: "g_session_receive",
      listening: true,
      secret_key: @key,
      encryption_mode: @mode,
      ssrc_map: %{@ssrc => "777"}
    }

    {:ok, state: state}
  end

  defp receive_packet(state, opus, seq) do
    packet = Crypto.encrypt_packet(opus, seq, 960 * seq, @ssrc, @key, @mode, seq)
    Session.handle_info({:udp, nil, {127, 0, 0, 1}, 50_000, packet}, state)
  end

  test "an audio frame is dispatched", %{state: state} do
    assert {:ok, _} = receive_packet(state, <<0xFC, 1, 2, 3>>, 1)
    assert_receive {:audio, %{opus: <<0xFC, 1, 2, 3>>, user_id: "777"}}, 1_000
  end

  test "a packet with no payload is not dispatched as audio", %{state: state} do
    assert {:ok, _} = receive_packet(state, <<>>, 2)
    refute_receive {:audio, _}, 200
  end

  test "nor is it counted as a DAVE decryption failure", %{state: state} do
    manager = EDA.Voice.Dave.Manager.new(1, 12_345, 67_890)
    assert {:ok, state} = receive_packet(%{state | dave_manager: manager}, <<>>, 3)
    assert state.dave_manager.decrypt_failures == 0
  end
end
