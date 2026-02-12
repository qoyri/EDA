defmodule EDA.Voice.CryptoTest do
  use ExUnit.Case, async: true

  alias EDA.Voice.Crypto

  describe "select_mode/1" do
    test "selects AES-256-GCM when available" do
      modes = ["aead_aes256_gcm_rtpsize", "aead_xchacha20_poly1305_rtpsize"]
      assert {:ok, "aead_aes256_gcm_rtpsize"} = Crypto.select_mode(modes)
    end

    test "falls back to XChaCha20 when AES not available" do
      modes = ["aead_xchacha20_poly1305_rtpsize", "some_other_mode"]
      assert {:ok, "aead_xchacha20_poly1305_rtpsize"} = Crypto.select_mode(modes)
    end

    test "returns :error when no supported mode available" do
      modes = ["xsalsa20_poly1305", "unknown_mode"]
      assert :error = Crypto.select_mode(modes)
    end

    test "returns :error for empty list" do
      assert :error = Crypto.select_mode([])
    end

    test "prefers AES over XChaCha20" do
      modes = ["aead_xchacha20_poly1305_rtpsize", "aead_aes256_gcm_rtpsize"]
      assert {:ok, "aead_aes256_gcm_rtpsize"} = Crypto.select_mode(modes)
    end
  end

  describe "rtp_header/3" do
    test "builds 12-byte RTP header" do
      header = Crypto.rtp_header(1, 960, 42)

      assert byte_size(header) == 12
      assert <<0x80, 0x78, 1::16-big, 960::32-big, 42::32-big>> = header
    end

    test "wraps sequence at 16 bits" do
      header = Crypto.rtp_header(65_535, 0, 0)
      <<0x80, 0x78, seq::16-big, _::binary>> = header
      assert seq == 65_535
    end

    test "handles zero values" do
      header = Crypto.rtp_header(0, 0, 0)
      assert <<0x80, 0x78, 0::16, 0::32, 0::32>> = header
    end

    test "encodes large timestamp and ssrc" do
      header = Crypto.rtp_header(100, 4_294_967_295, 4_294_967_295)
      <<0x80, 0x78, 100::16-big, ts::32-big, ssrc::32-big>> = header
      assert ts == 4_294_967_295
      assert ssrc == 4_294_967_295
    end
  end

  describe "encrypt_packet/7 and decrypt_packet/3 with AES" do
    @secret_key :crypto.strong_rand_bytes(32)
    @mode "aead_aes256_gcm_rtpsize"

    test "round-trip encrypt/decrypt produces original data" do
      opus_frame = :crypto.strong_rand_bytes(160)

      encrypted =
        Crypto.encrypt_packet(opus_frame, 1, 960, 42, @secret_key, @mode, 0)

      assert {:ok, decrypted} = Crypto.decrypt_packet(encrypted, @secret_key, @mode)
      assert decrypted == opus_frame
    end

    test "different nonces produce different ciphertext" do
      opus_frame = :crypto.strong_rand_bytes(160)

      encrypted1 = Crypto.encrypt_packet(opus_frame, 1, 960, 42, @secret_key, @mode, 0)
      encrypted2 = Crypto.encrypt_packet(opus_frame, 1, 960, 42, @secret_key, @mode, 1)

      assert encrypted1 != encrypted2
    end

    test "RTP header is plaintext in encrypted packet" do
      opus_frame = :crypto.strong_rand_bytes(160)
      encrypted = Crypto.encrypt_packet(opus_frame, 5, 4800, 99, @secret_key, @mode, 0)

      <<header::binary-size(12), _rest::binary>> = encrypted
      assert header == Crypto.rtp_header(5, 4800, 99)
    end

    test "decryption fails with wrong key" do
      opus_frame = :crypto.strong_rand_bytes(160)
      wrong_key = :crypto.strong_rand_bytes(32)

      encrypted = Crypto.encrypt_packet(opus_frame, 1, 960, 42, @secret_key, @mode, 0)
      assert :error = Crypto.decrypt_packet(encrypted, wrong_key, @mode)
    end
  end

  describe "encrypt_packet/7 and decrypt_packet/3 with XChaCha20" do
    @secret_key_chacha :crypto.strong_rand_bytes(32)
    @mode_chacha "aead_xchacha20_poly1305_rtpsize"

    test "round-trip encrypt/decrypt produces original data" do
      opus_frame = :crypto.strong_rand_bytes(160)

      encrypted =
        Crypto.encrypt_packet(opus_frame, 1, 960, 42, @secret_key_chacha, @mode_chacha, 0)

      assert {:ok, decrypted} = Crypto.decrypt_packet(encrypted, @secret_key_chacha, @mode_chacha)
      assert decrypted == opus_frame
    end

    test "different nonces produce different ciphertext" do
      opus_frame = :crypto.strong_rand_bytes(160)

      encrypted1 =
        Crypto.encrypt_packet(opus_frame, 1, 960, 42, @secret_key_chacha, @mode_chacha, 0)

      encrypted2 =
        Crypto.encrypt_packet(opus_frame, 1, 960, 42, @secret_key_chacha, @mode_chacha, 1)

      assert encrypted1 != encrypted2
    end

    test "RTP header is plaintext in encrypted packet" do
      opus_frame = :crypto.strong_rand_bytes(160)

      encrypted =
        Crypto.encrypt_packet(opus_frame, 5, 4800, 99, @secret_key_chacha, @mode_chacha, 0)

      <<header::binary-size(12), _rest::binary>> = encrypted
      assert header == Crypto.rtp_header(5, 4800, 99)
    end

    test "decryption fails with wrong key" do
      opus_frame = :crypto.strong_rand_bytes(160)
      wrong_key = :crypto.strong_rand_bytes(32)

      encrypted =
        Crypto.encrypt_packet(opus_frame, 1, 960, 42, @secret_key_chacha, @mode_chacha, 0)

      assert :error = Crypto.decrypt_packet(encrypted, wrong_key, @mode_chacha)
    end
  end
end
