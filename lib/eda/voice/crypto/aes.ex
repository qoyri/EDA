defmodule EDA.Voice.Crypto.AES do
  @moduledoc """
  AES-256-GCM encryption for Discord voice.

  Uses Erlang's built-in `:crypto` module. Implements the
  `aead_aes256_gcm_rtpsize` mode where the RTP header stays plaintext.
  """

  @aad_length 12
  @tag_length 16
  @nonce_length 12

  @doc """
  Encrypts an audio frame using AES-256-GCM.

  The RTP header (first 12 bytes) is used as AAD (additional authenticated data)
  and stays plaintext. A 4-byte nonce is appended to the packet.
  """
  @spec encrypt(binary(), binary(), integer()) :: binary()
  def encrypt(frame, secret_key, nonce) do
    nonce_bytes = <<nonce::32>>
    iv = nonce_bytes <> <<0::unit(8)-size(8)>>

    <<rtp_header::binary-size(@aad_length), payload::binary>> = frame

    {ciphertext, tag} =
      :crypto.crypto_one_time_aead(
        :aes_256_gcm,
        secret_key,
        iv,
        payload,
        rtp_header,
        @tag_length,
        true
      )

    rtp_header <> ciphertext <> tag <> nonce_bytes
  end

  @doc """
  Decrypts an AES-256-GCM encrypted voice packet.

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

    iv = nonce_bytes <> <<0::unit(8)-size(8)>>

    case :crypto.crypto_one_time_aead(
           :aes_256_gcm,
           secret_key,
           iv,
           ciphertext,
           rtp_header,
           tag,
           false
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
