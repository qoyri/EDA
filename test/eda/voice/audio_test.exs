defmodule EDA.Voice.AudioTest do
  use ExUnit.Case, async: true

  alias EDA.Voice.{Audio, Crypto, State}
  alias EDA.Voice.Dave.Manager

  setup do
    previous_trap_exit = Process.flag(:trap_exit, true)

    {:ok, recv_socket} = :gen_udp.open(0, [:binary, active: false, ip: {127, 0, 0, 1}])
    {:ok, {_ip, port}} = :inet.sockname(recv_socket)
    {:ok, send_socket} = :gen_udp.open(0, [:binary, active: false])

    on_exit(fn ->
      :gen_udp.close(send_socket)
      :gen_udp.close(recv_socket)
      Process.flag(:trap_exit, previous_trap_exit)
    end)

    {:ok, recv_socket: recv_socket, send_socket: send_socket, voice_port: port}
  end

  test "raw playback sends encrypted RTP packets in passthrough mode", ctx do
    frame = :crypto.strong_rand_bytes(160)
    secret_key = :crypto.strong_rand_bytes(32)

    voice_state =
      build_voice_state(
        ctx.send_socket,
        ctx.voice_port,
        secret_key,
        Manager.new(0, 12_345, 67_890)
      )

    guild_id = "audio_passthrough_#{System.unique_integer([:positive])}"
    pid = Audio.play(guild_id, [frame], :raw, voice_state)
    monitor = Process.monitor(pid)

    assert {:ok, {_addr, _port, packet}} = :gen_udp.recv(ctx.recv_socket, 0, 1_000)

    assert {:ok, decrypted} =
             Crypto.decrypt_packet(packet, secret_key, voice_state.encryption_mode)

    assert decrypted == frame
    assert_receive {:DOWN, ^monitor, :process, ^pid, :normal}, 1_000
  end

  test "raw playback fails closed when DAVE media encryption is unavailable", ctx do
    frame = :crypto.strong_rand_bytes(160)
    secret_key = :crypto.strong_rand_bytes(32)

    voice_state =
      build_voice_state(ctx.send_socket, ctx.voice_port, secret_key, %Manager{
        protocol_version: 1,
        mls_session: nil
      })

    guild_id = "audio_fail_closed_#{System.unique_integer([:positive])}"
    pid = Audio.play(guild_id, [frame], :raw, voice_state)
    monitor = Process.monitor(pid)

    assert {:error, :timeout} = :gen_udp.recv(ctx.recv_socket, 0, 250)
    assert_receive {:DOWN, ^monitor, :process, ^pid, :normal}, 1_000
  end

  defp build_voice_state(send_socket, voice_port, secret_key, dave_manager) do
    %State{
      ssrc: 42,
      secret_key: secret_key,
      encryption_mode: "aead_aes256_gcm_rtpsize",
      udp_socket: send_socket,
      ip: "127.0.0.1",
      port: voice_port,
      sequence: 1,
      timestamp: 960,
      nonce: 0,
      dave_manager: dave_manager
    }
  end
end
