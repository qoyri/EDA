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

  Returns `{:ok, opus_data}` or `:error`.
  """
  @spec decrypt_packet(binary(), binary(), String.t()) :: {:ok, binary()} | :error
  def decrypt_packet(packet, secret_key, mode) do
    case mode do
      "aead_aes256_gcm_rtpsize" -> AES.decrypt(packet, secret_key)
      "aead_xchacha20_poly1305_rtpsize" -> ChaCha.decrypt(packet, secret_key)
    end
  end
end
