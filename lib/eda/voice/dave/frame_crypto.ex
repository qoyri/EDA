defmodule EDA.Voice.Dave.FrameCrypto do
  @moduledoc """
  Per-frame AES-128-GCM encryption for the DAVE (Discord Audio Video E2EE) protocol.

  For Opus audio, the first byte (TOC byte) remains unencrypted (authenticated only).
  The supplemental data is appended at the end of the frame.

  Frame format (output):
  ```
  [unencrypted ranges (clear, authenticated)]
  [ciphertext (encrypted)]
  --- supplemental bytes ---
  [truncated GCM tag (8 bytes)]
  [nonce (LEB128 varint)]
  [unencrypted ranges descriptor (LEB128 pairs)]
  [supplemental_bytes_size (1 byte)]
  [magic marker 0xFA 0xFA (2 bytes)]
  ```

  Note: In production, the NIF (`EDA.Voice.Dave.Native.encrypt_opus/2`) handles
  encryption/decryption via the davey Rust crate. This module provides a pure
  Elixir implementation for testing and reference.
  """

  @truncated_tag_bytes 8
  @full_nonce_bytes 12
  @nonce_offset @full_nonce_bytes - 4
  @magic_marker <<0xFA, 0xFA>>
  @magic_marker_size 2
  @size_byte 1

  @doc """
  Encrypts an Opus frame using AES-128-GCM for DAVE E2EE.

  For Opus, the first byte (TOC) stays unencrypted but is used as AAD.
  """
  @spec encrypt(binary(), binary(), non_neg_integer()) :: binary()
  def encrypt(opus_frame, sender_key, nonce)
      when byte_size(sender_key) == 16 and byte_size(opus_frame) >= 1 do
    # Opus: first byte is unencrypted (TOC byte)
    <<unencrypted::binary-1, plaintext::binary>> = opus_frame

    iv = build_iv(nonce)

    {ciphertext, truncated_tag} =
      :crypto.crypto_one_time_aead(
        :aes_128_gcm,
        sender_key,
        iv,
        plaintext,
        unencrypted,
        @truncated_tag_bytes,
        true
      )

    nonce_leb128 = encode_leb128(nonce)
    # Unencrypted ranges for Opus: one range at offset 0, size 1
    ranges_descriptor = encode_leb128(0) <> encode_leb128(1)

    supplemental_content =
      truncated_tag <> nonce_leb128 <> ranges_descriptor

    supplemental_size =
      byte_size(supplemental_content) + @size_byte + @magic_marker_size

    <<unencrypted::binary, ciphertext::binary, supplemental_content::binary, supplemental_size,
      @magic_marker::binary>>
  end

  @doc """
  Decrypts a DAVE-encrypted frame using AES-128-GCM.

  Returns `{:ok, opus_frame}` or `:error` if decryption/parsing fails.
  """
  @spec decrypt(binary(), binary()) :: {:ok, binary()} | :error
  def decrypt(encrypted_frame, sender_key) when byte_size(sender_key) == 16 do
    min_size = @truncated_tag_bytes + @size_byte + @magic_marker_size
    if byte_size(encrypted_frame) < min_size, do: throw(:too_small)

    frame_size = byte_size(encrypted_frame)

    # Check magic marker
    marker_offset = frame_size - @magic_marker_size
    <<_::binary-size(^marker_offset), marker::binary-2>> = encrypted_frame
    if marker != @magic_marker, do: throw(:no_marker)

    # Read supplemental bytes size
    size_offset = frame_size - @magic_marker_size - @size_byte
    supplemental_size = :binary.at(encrypted_frame, size_offset)
    if frame_size < supplemental_size, do: throw(:bad_size)

    # Extract supplemental bytes (excluding size byte and marker)
    supp_start = frame_size - supplemental_size
    supp_content_size = supplemental_size - @size_byte - @magic_marker_size

    <<_::binary-size(^supp_start), supplemental::binary-size(^supp_content_size),
      _size_and_marker::binary>> = encrypted_frame

    # Parse tag
    if byte_size(supplemental) < @truncated_tag_bytes, do: throw(:bad_tag)

    <<truncated_tag::binary-size(@truncated_tag_bytes), after_tag::binary>> = supplemental

    # Parse nonce (LEB128)
    {nonce, nonce_size} = decode_leb128(after_tag)
    <<_::binary-size(^nonce_size), ranges_data::binary>> = after_tag

    # Parse unencrypted ranges
    ranges = parse_unencrypted_ranges(ranges_data)

    # Split frame body into unencrypted (AAD) and ciphertext
    body_size = frame_size - supplemental_size
    <<body::binary-size(^body_size), _::binary>> = encrypted_frame

    {authenticated, ciphertext_bytes} = split_by_ranges(body, ranges)

    iv = build_iv(nonce)

    case :crypto.crypto_one_time_aead(
           :aes_128_gcm,
           sender_key,
           iv,
           ciphertext_bytes,
           authenticated,
           truncated_tag,
           false
         ) do
      plaintext when is_binary(plaintext) ->
        {:ok, reconstruct_frame(ranges, authenticated, plaintext, body_size)}

      :error ->
        :error
    end
  catch
    :throw, _ -> :error
  end

  def decrypt(_encrypted_frame, _sender_key), do: :error

  # Build a 12-byte IV from a truncated 4-byte nonce
  defp build_iv(nonce) do
    <<0::size(@nonce_offset * 8), nonce::little-32>>
  end

  # Split body into authenticated (unencrypted ranges) and ciphertext
  defp split_by_ranges(body, []), do: {<<>>, body}

  defp split_by_ranges(body, ranges) do
    {auth_parts, cipher_parts, _pos} =
      Enum.reduce(ranges, {[], [], 0}, fn {offset, size}, {auth, cipher, pos} ->
        # Bytes before this range are encrypted
        gap = offset - pos

        cipher =
          if gap > 0 do
            [binary_part(body, pos, gap) | cipher]
          else
            cipher
          end

        auth = [binary_part(body, offset, size) | auth]
        {auth, cipher, offset + size}
      end)

    # Remaining bytes after last range are encrypted
    last_end =
      case List.last(ranges) do
        {offset, size} -> offset + size
        nil -> 0
      end

    remaining = byte_size(body) - last_end

    cipher_parts =
      if remaining > 0 do
        [binary_part(body, last_end, remaining) | cipher_parts]
      else
        cipher_parts
      end

    authenticated = auth_parts |> Enum.reverse() |> IO.iodata_to_binary()
    ciphertext = cipher_parts |> Enum.reverse() |> IO.iodata_to_binary()
    {authenticated, ciphertext}
  end

  # Reconstruct original frame from ranges, authenticated, and decrypted data
  defp reconstruct_frame([], _authenticated, plaintext, _size), do: plaintext

  defp reconstruct_frame(ranges, authenticated, plaintext, frame_size) do
    output = :binary.copy(<<0>>, frame_size)

    {output, _auth_idx, _plain_idx} =
      Enum.reduce(ranges, {output, 0, 0}, fn {offset, size}, {out, auth_idx, plain_idx} ->
        # Fill encrypted bytes before this range
        gap = offset - (auth_idx + plain_idx)

        {out, plain_idx} =
          if gap > 0 do
            plain_chunk = binary_part(plaintext, plain_idx, gap)
            pos = offset - gap
            out = replace_at(out, pos, plain_chunk)
            {out, plain_idx + gap}
          else
            {out, plain_idx}
          end

        # Fill unencrypted (authenticated) bytes
        auth_chunk = binary_part(authenticated, auth_idx, size)
        out = replace_at(out, offset, auth_chunk)
        {out, auth_idx + size, plain_idx}
      end)

    # Fill remaining plaintext after last range
    last_end =
      case List.last(ranges) do
        {o, s} -> o + s
        nil -> 0
      end

    remaining = frame_size - last_end

    if remaining > 0 do
      plain_used = frame_size - byte_size(authenticated) - remaining
      chunk = binary_part(plaintext, plain_used, remaining)
      replace_at(output, last_end, chunk)
    else
      output
    end
  end

  defp replace_at(binary, offset, replacement) do
    tail_start = offset + byte_size(replacement)
    tail_size = byte_size(binary) - tail_start

    <<head::binary-size(^offset), _::binary-size(byte_size(^replacement)),
      tail::binary-size(^tail_size)>> = binary

    <<head::binary, replacement::binary, tail::binary>>
  end

  defp parse_unencrypted_ranges(<<>>), do: []

  defp parse_unencrypted_ranges(data) do
    do_parse_ranges(data, [])
  end

  defp do_parse_ranges(<<>>, acc), do: Enum.reverse(acc)

  defp do_parse_ranges(data, acc) do
    {offset, size1} = decode_leb128(data)
    <<_::binary-size(^size1), rest::binary>> = data
    {range_size, size2} = decode_leb128(rest)
    <<_::binary-size(^size2), remaining::binary>> = rest
    do_parse_ranges(remaining, [{offset, range_size} | acc])
  end

  @doc false
  def encode_leb128(value) when value < 128, do: <<value>>

  def encode_leb128(value) do
    <<1::1, value::7, encode_leb128(Bitwise.bsr(value, 7))::binary>>
  end

  defp decode_leb128(data), do: do_decode_leb128(data, 0, 0)

  defp do_decode_leb128(<<byte, rest::binary>>, shift, acc) do
    value = Bitwise.bor(acc, Bitwise.bsl(Bitwise.band(byte, 0x7F), shift))

    if Bitwise.band(byte, 0x80) == 0x80 do
      do_decode_leb128(rest, shift + 7, value)
    else
      {value, div(shift, 7) + 1}
    end
  end
end
