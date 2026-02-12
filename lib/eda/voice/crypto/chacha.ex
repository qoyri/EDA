defmodule EDA.Voice.Crypto.ChaCha do
  @moduledoc """
  XChaCha20-Poly1305 encryption for Discord voice.

  Uses the `salchicha` library (pure Elixir, no NIF). Implements the
  `aead_xchacha20_poly1305_rtpsize` mode.
  """

  @aad_length 12
  @tag_length 16
  @nonce_length 24

  @doc """
  Encrypts an audio frame using XChaCha20-Poly1305.

  The RTP header (first 12 bytes) is used as AAD and stays plaintext.
  A 4-byte nonce is appended to the packet.
  """
  @spec encrypt(binary(), binary(), integer()) :: binary()
  def encrypt(frame, secret_key, nonce) do
    nonce_bytes = <<nonce::32>>
    iv = nonce_bytes <> <<0::unit(8)-size(20)>>

    <<rtp_header::binary-size(@aad_length), payload::binary>> = frame

    {ciphertext, tag} =
      Salchicha.xchacha20_poly1305_encrypt_detached(payload, iv, secret_key, rtp_header)

    rtp_header <> IO.iodata_to_binary(ciphertext) <> tag <> nonce_bytes
  end

  @doc """
  Decrypts an XChaCha20-Poly1305 encrypted voice packet.

  Returns `{:ok, plaintext}` or `:error`.
  """
  @spec decrypt(binary(), binary()) :: {:ok, binary()} | :error
  def decrypt(packet, secret_key) do
    packet_size = byte_size(packet)
    nonce_offset = packet_size - 4
    tag_offset = nonce_offset - @tag_length

    <<rtp_header::binary-size(@aad_length), ciphertext_and_tag::binary>> =
      binary_part(packet, 0, nonce_offset)

    <<nonce_bytes::binary-size(4)>> = binary_part(packet, nonce_offset, 4)

    ciphertext_len = tag_offset - @aad_length

    <<ciphertext::binary-size(ciphertext_len), tag::binary-size(@tag_length)>> =
      ciphertext_and_tag

    iv = nonce_bytes <> <<0::unit(8)-size(20)>>

    case Salchicha.xchacha20_poly1305_decrypt_detached(
           ciphertext,
           iv,
           secret_key,
           rtp_header,
           tag
         ) do
      plaintext when is_binary(plaintext) -> {:ok, plaintext}
      :error -> :error
    end
  end

  @doc """
  Returns the nonce byte length for this encryption mode.
  """
  def nonce_length, do: @nonce_length
end
