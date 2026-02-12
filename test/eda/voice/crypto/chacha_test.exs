defmodule EDA.Voice.Crypto.ChaChaTest do
  use ExUnit.Case, async: true

  alias EDA.Voice.Crypto.ChaCha

  @secret_key :crypto.strong_rand_bytes(32)

  describe "encrypt/3" do
    test "produces encrypted packet larger than input" do
      frame = :crypto.strong_rand_bytes(12 + 160)
      encrypted = ChaCha.encrypt(frame, @secret_key, 0)

      # encrypted = rtp_header(12) + ciphertext(160) + tag(16) + nonce(4) = 192
      assert byte_size(encrypted) == 12 + 160 + 16 + 4
    end

    test "preserves RTP header as plaintext" do
      rtp_header = <<0x80, 0x78, 1::16-big, 960::32-big, 42::32-big>>
      frame = rtp_header <> :crypto.strong_rand_bytes(160)
      encrypted = ChaCha.encrypt(frame, @secret_key, 0)

      <<header::binary-size(12), _rest::binary>> = encrypted
      assert header == rtp_header
    end

    test "appends 4-byte nonce at the end" do
      frame = :crypto.strong_rand_bytes(12 + 80)
      encrypted = ChaCha.encrypt(frame, @secret_key, 42)

      nonce_bytes = binary_part(encrypted, byte_size(encrypted) - 4, 4)
      assert <<42::32>> = nonce_bytes
    end
  end

  describe "decrypt/2" do
    test "round-trip encrypt/decrypt" do
      frame = :crypto.strong_rand_bytes(12 + 160)
      encrypted = ChaCha.encrypt(frame, @secret_key, 0)

      assert {:ok, decrypted} = ChaCha.decrypt(encrypted, @secret_key)
      <<_rtp::binary-size(12), payload::binary>> = frame
      assert decrypted == payload
    end

    test "works with different nonce values" do
      for nonce <- [0, 1, 255, 65_535, 16_777_215] do
        frame = :crypto.strong_rand_bytes(12 + 80)
        encrypted = ChaCha.encrypt(frame, @secret_key, nonce)
        assert {:ok, _} = ChaCha.decrypt(encrypted, @secret_key)
      end
    end

    test "fails with wrong secret key" do
      frame = :crypto.strong_rand_bytes(12 + 160)
      encrypted = ChaCha.encrypt(frame, @secret_key, 0)

      wrong_key = :crypto.strong_rand_bytes(32)
      assert :error = ChaCha.decrypt(encrypted, wrong_key)
    end

    test "fails with tampered ciphertext" do
      frame = :crypto.strong_rand_bytes(12 + 160)
      encrypted = ChaCha.encrypt(frame, @secret_key, 0)

      <<header::binary-size(12), byte, rest::binary>> = encrypted
      tampered = header <> <<Bitwise.bxor(byte, 0xFF)>> <> rest

      assert :error = ChaCha.decrypt(tampered, @secret_key)
    end
  end

  describe "nonce_length/0" do
    test "returns 24" do
      assert ChaCha.nonce_length() == 24
    end
  end
end
