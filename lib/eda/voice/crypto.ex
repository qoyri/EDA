defmodule EDA.Voice.Crypto do
  @moduledoc """
  Encryption dispatch for Discord voice.

  Selects the appropriate encryption module based on the negotiated mode
  and handles RTP packet construction.
  """

  alias EDA.Voice.Crypto.{AES, ChaCha}

  @preferred_modes [
    "aead_aes256_gcm_rtpsize",
    "aead_xchacha20_poly1305_rtpsize"
  ]

  @doc """
  Selects the best encryption mode from the server's available modes.

  Returns `{:ok, mode}` or `:error` if no supported mode is available.
  """
  @spec select_mode([String.t()]) :: {:ok, String.t()} | :error
  def select_mode(available_modes) do
    case Enum.find(@preferred_modes, &(&1 in available_modes)) do
      nil -> :error
      mode -> {:ok, mode}
    end
  end

  @doc """
  Builds an RTP header.

  Format: `<<0x80, 0x78, sequence::16-big, timestamp::32-big, ssrc::32-big>>`
  """
  @spec rtp_header(integer(), integer(), integer()) :: binary()
  def rtp_header(sequence, timestamp, ssrc) do
    <<0x80, 0x78, sequence::16-big, timestamp::32-big, ssrc::32-big>>
  end

  @doc """
  Encrypts an opus frame with the RTP header prepended.

  Returns the full encrypted packet ready to send over UDP.
  """
  @spec encrypt_packet(binary(), integer(), integer(), integer(), binary(), String.t(), integer()) ::
          binary()
  def encrypt_packet(opus_frame, sequence, timestamp, ssrc, secret_key, mode, nonce) do
    header = rtp_header(sequence, timestamp, ssrc)
    frame = header <> opus_frame

    case mode do
      "aead_aes256_gcm_rtpsize" -> AES.encrypt(frame, secret_key, nonce)
      "aead_xchacha20_poly1305_rtpsize" -> ChaCha.encrypt(frame, secret_key, nonce)
    end
  end

  @doc """
  Decrypts a received voice packet.

  For `_rtpsize` modes, the AAD is the RTP header + extension preamble (if present).
  The extension elements themselves are encrypted and must be stripped after decryption.

  Returns `{:ok, opus_data}` or `:error`.
  """
  @spec decrypt_packet(binary(), binary(), String.t()) :: {:ok, binary()} | :error
  def decrypt_packet(<<_v::2, p::1, _::5, _::binary>> = packet, secret_key, mode) do
    {aad_size, ext_data_size} = rtpsize_aad(packet)

    result =
      case mode do
        "aead_aes256_gcm_rtpsize" -> AES.decrypt(packet, secret_key, aad_size)
        "aead_xchacha20_poly1305_rtpsize" -> ChaCha.decrypt(packet, secret_key, aad_size)
      end

    case result do
      {:ok, plaintext} ->
        {:ok, strip_rtp_extras(plaintext, ext_data_size, p)}

      :error ->
        :error
    end
  end

  # Strip extension elements from the front and padding from the back
  defp strip_rtp_extras(plaintext, ext_data_size, padding_flag) do
    <<_ext::binary-size(^ext_data_size), rest::binary>> = plaintext

    if padding_flag == 1 and byte_size(rest) > 0 do
      pad_len = :binary.last(rest)
      binary_part(rest, 0, byte_size(rest) - pad_len)
    else
      rest
    end
  end

  # For _rtpsize modes: AAD = fixed header + CSRC list + extension preamble (4 bytes).
  # Extension elements are encrypted (part of ciphertext), not part of AAD.
  defp rtpsize_aad(<<_v::2, _p::1, x::1, cc::4, _rest::binary>> = packet) do
    base = 12 + cc * 4

    if x == 1 and byte_size(packet) >= base + 4 do
      <<_::binary-size(^base), _profile::16, ext_len::16, _::binary>> = packet
      {base + 4, ext_len * 4}
    else
      {base, 0}
    end
  end
end
