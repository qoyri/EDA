defmodule EDA.Voice.Audio do
  @moduledoc """
  Handles UDP socket management, IP discovery, audio encoding via FFmpeg,
  and the player loop for sending opus frames over RTP.
  """

  require Logger

  alias EDA.Voice.{Crypto, Ogg, Payload, Session}

  @ip_discovery_type 0x01
  @ip_discovery_length 70
  # 20ms in microseconds — used for monotonic timing
  @frame_duration_us 20_000
  @opus_frame_samples 960
  @silence_frames 5

  # IP Discovery

  @doc """
  Opens a UDP socket and performs IP discovery against the voice server.

  Returns `{:ok, socket, our_ip, our_port}` or `{:error, reason}`.
  """
  @spec open_udp_and_discover(String.t(), integer(), integer()) ::
          {:ok, port(), String.t(), integer()} | {:error, term()}
  def open_udp_and_discover(ip, port, ssrc) do
    with {:ok, socket} <- :gen_udp.open(0, [:binary, active: false]),
         :ok <- send_ip_discovery(socket, ip, port, ssrc),
         {:ok, our_ip, our_port} <- recv_ip_discovery(socket) do
      {:ok, socket, our_ip, our_port}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp send_ip_discovery(socket, ip, port, ssrc) do
    packet =
      <<@ip_discovery_type::16, @ip_discovery_length::16, ssrc::32>> <>
        String.pad_trailing(ip, 64, <<0>>) <>
        <<port::16>>

    {:ok, ip_tuple} = ip |> String.to_charlist() |> :inet_parse.address()
    :gen_udp.send(socket, ip_tuple, port, packet)
  end

  defp recv_ip_discovery(socket) do
    case :gen_udp.recv(socket, 74, 5000) do
      {:ok, {_addr, _port, <<2::16, 70::16, _ssrc::32, ip::bitstring-size(512), port::16>>}} ->
        our_ip = ip |> String.trim(<<0>>)
        {:ok, our_ip, port}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Audio Playback

  @doc """
  Starts playing audio from the given input. Runs as a linked process.

  Types:
  - `:url` - URL or file path passed to ffmpeg
  - `:raw` - Raw opus frames (binary stream)

  Returns the pid of the player process.
  """
  @spec play(String.t(), String.t() | Enumerable.t(), atom(), map()) :: pid()
  def play(guild_id, input, type, voice_state) do
    spawn_link(fn ->
      player_loop(guild_id, input, type, voice_state)
    end)
  end

  defp player_loop(guild_id, input, :url, voice_state) do
    args = build_ffmpeg_args(input)

    Logger.info("Starting ffmpeg: #{inspect(args)}")

    port =
      Port.open({:spawn_executable, ffmpeg_path()}, [
        :binary,
        :exit_status,
        :use_stdio,
        :stream,
        args: args
      ])

    # Must send speaking before any audio data
    Session.send_payload(guild_id, Payload.speaking(voice_state.ssrc, true))

    stream_from_port(port, guild_id, voice_state)

    send_silence(guild_id, voice_state)
    Session.send_payload(guild_id, Payload.speaking(voice_state.ssrc, false))

    EDA.Voice.playback_finished(guild_id)
  end

  defp player_loop(guild_id, frames, :raw, voice_state) do
    Session.send_payload(guild_id, Payload.speaking(voice_state.ssrc, true))

    send_frames(
      frames,
      guild_id,
      voice_state,
      voice_state.sequence,
      voice_state.timestamp,
      voice_state.nonce
    )

    send_silence(guild_id, voice_state)
    Session.send_payload(guild_id, Payload.speaking(voice_state.ssrc, false))

    EDA.Voice.playback_finished(guild_id)
  end

  # FFmpeg outputs OGG pages via `-f ogg`. We parse those pages to get individual
  # opus frames with guaranteed boundaries, then send each frame with monotonic
  # clock-based timing to prevent drift.
  defp stream_from_port(port, _guild_id, voice_state) do
    stream = %{
      vs: voice_state,
      seq: voice_state.sequence,
      ts: voice_state.timestamp,
      nonce: voice_state.nonce,
      frame_idx: 0,
      start: System.monotonic_time(:microsecond),
      buffer: <<>>,
      skip: 2
    }

    do_stream(port, stream)
  end

  defp do_stream(port, %{buffer: buffer, skip: skip} = s) do
    receive do
      {^port, {:data, chunk}} ->
        {frames, remaining, new_skip} =
          Ogg.extract_frames(<<buffer::binary, chunk::binary>>, skip)

        updated = send_timed_frames(frames, %{s | buffer: remaining, skip: new_skip})
        do_stream(port, updated)

      {^port, {:exit_status, 0}} ->
        Logger.debug("FFmpeg finished successfully")
        :ok

      {^port, {:exit_status, status}} ->
        Logger.warning("FFmpeg exited with status #{status}")
        :ok
    after
      10_000 ->
        Port.close(port)
        Logger.warning("FFmpeg timed out")
        :ok
    end
  end

  @diag_window 500

  defp send_timed_frames([], stream), do: stream

  defp send_timed_frames([frame | rest], %{vs: vs, seq: seq, ts: ts, nonce: nonce} = s) do
    now = System.monotonic_time(:microsecond)
    send_single_frame(frame, vs, seq, ts, nonce)

    next_idx = s.frame_idx + 1

    # Collect diagnostic data
    slot = rem(s.frame_idx, @diag_window)

    Process.put({:diag, slot}, %{
      idx: s.frame_idx,
      size: byte_size(frame),
      actual_us: now - s.start,
      drift_us: now - s.start - s.frame_idx * @frame_duration_us
    })

    if slot == @diag_window - 1 do
      dump_diagnostics(div(s.frame_idx, @diag_window))
    end

    target = s.start + next_idx * @frame_duration_us
    sleep_now = System.monotonic_time(:microsecond)
    sleep_us = target - sleep_now
    if sleep_us > 1000, do: Process.sleep(div(sleep_us, 1000))

    send_timed_frames(rest, %{
      s
      | seq: band(seq + 1, 0xFFFF),
        ts: ts + @opus_frame_samples,
        nonce: nonce + 1,
        frame_idx: next_idx
    })
  end

  defp dump_diagnostics(window_num) do
    diags =
      0..(@diag_window - 1)
      |> Enum.map(fn i -> Process.get({:diag, i}) end)
      |> Enum.reject(&is_nil/1)

    sizes = Enum.map(diags, & &1.size)
    merged_count = Enum.count(sizes, &(&1 > 400))

    drifts = Enum.map(diags, & &1.drift_us)

    intervals =
      diags
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.map(fn [a, b] -> b.actual_us - a.actual_us end)

    total_elapsed = List.last(diags).actual_us
    total_expected = (@diag_window - 1) * @frame_duration_us

    Logger.info("""
    === AUDIO DIAGNOSTICS window=#{window_num} (#{@diag_window} frames) ===
    Frame sizes: min=#{Enum.min(sizes)} max=#{Enum.max(sizes)} avg=#{div(Enum.sum(sizes), length(sizes))} merged(>400B)=#{merged_count}
    Drift (µs):  min=#{Enum.min(drifts)} max=#{Enum.max(drifts)} avg=#{div(Enum.sum(drifts), length(drifts))}
    Late(>5ms)=#{Enum.count(drifts, &(&1 > 5_000))} Early(<-5ms)=#{Enum.count(drifts, &(&1 < -5_000))}
    Intervals (µs): min=#{Enum.min(intervals)} max=#{Enum.max(intervals)} avg=#{div(Enum.sum(intervals), length(intervals))}
    Jitter: slow(>30ms)=#{Enum.count(intervals, &(&1 > 30_000))} fast(<10ms)=#{Enum.count(intervals, &(&1 < 10_000))}
    Total: elapsed=#{div(total_elapsed, 1000)}ms expected=#{div(total_expected, 1000)}ms diff=#{div(total_elapsed - total_expected, 1000)}ms
    === END DIAGNOSTICS ===
    """)

    Enum.each(0..(@diag_window - 1), fn i -> Process.delete({:diag, i}) end)
  end

  defp send_frames(frames, _guild_id, voice_state, seq, timestamp, nonce) when is_list(frames) do
    start = System.monotonic_time(:microsecond)

    Enum.reduce(frames, {seq, timestamp, nonce, 0}, fn frame, {s, t, n, i} ->
      send_single_frame(frame, voice_state, s, t, n)

      target = start + (i + 1) * @frame_duration_us
      now = System.monotonic_time(:microsecond)
      sleep_us = target - now
      if sleep_us > 1000, do: Process.sleep(div(sleep_us, 1000))

      {band(s + 1, 0xFFFF), t + @opus_frame_samples, n + 1, i + 1}
    end)
  end

  defp send_single_frame(frame, voice_state, seq, timestamp, nonce) do
    packet =
      Crypto.encrypt_packet(
        frame,
        seq,
        timestamp,
        voice_state.ssrc,
        voice_state.secret_key,
        voice_state.encryption_mode,
        nonce
      )

    :gen_udp.send(
      voice_state.udp_socket,
      String.to_charlist(voice_state.ip),
      voice_state.port,
      packet
    )
  end

  defp send_silence(guild_id, voice_state) do
    silence = <<0xF8, 0xFF, 0xFE>>
    frames = List.duplicate(silence, @silence_frames)

    send_frames(
      frames,
      guild_id,
      voice_state,
      voice_state.sequence,
      voice_state.timestamp,
      voice_state.nonce
    )
  end

  # Listening (incoming audio)

  @doc """
  Receives `count` voice packets from the UDP socket.

  Returns a list of `{ssrc, opus_data}` tuples.
  """
  @spec listen(port(), binary(), String.t(), integer()) :: [{integer(), binary()}]
  def listen(socket, secret_key, mode, count) do
    :inet.setopts(socket, active: false)

    Enum.reduce_while(1..count, [], fn _, acc ->
      case recv_and_decrypt(socket, secret_key, mode) do
        {:ok, ssrc, opus_data} -> {:cont, [{ssrc, opus_data} | acc]}
        :skip -> {:cont, acc}
        :timeout -> {:halt, acc}
      end
    end)
    |> Enum.reverse()
  end

  defp recv_and_decrypt(socket, secret_key, mode) do
    case :gen_udp.recv(socket, 0, 1000) do
      {:ok, {_addr, _port, packet}} ->
        <<_ver, _type, _seq::16, _ts::32, ssrc::32-big>> = binary_part(packet, 0, 12)

        case Crypto.decrypt_packet(packet, secret_key, mode) do
          {:ok, opus_data} -> {:ok, ssrc, opus_data}
          :error -> :skip
        end

      {:error, :timeout} ->
        :timeout
    end
  end

  # FFmpeg helpers

  defp build_ffmpeg_args(input) do
    [
      "-i",
      input,
      "-ac",
      "2",
      "-ar",
      "48000",
      "-f",
      "ogg",
      "-page_duration",
      "20000",
      "-map",
      "0:a",
      "-acodec",
      "libopus",
      "-b:a",
      "128000",
      "-frame_duration",
      "20",
      "-application",
      "audio",
      "-loglevel",
      "warning",
      "pipe:1"
    ]
  end

  defp ffmpeg_path do
    System.find_executable("ffmpeg") || "ffmpeg"
  end

  defp band(value, mask), do: Bitwise.band(value, mask)
end
