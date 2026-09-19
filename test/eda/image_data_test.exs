defmodule EDA.ImageDataTest do
  @moduledoc """
  Covers the data URIs Discord calls *image data*.

  The point of this module is that it refuses, locally and with a readable message, what
  Discord would refuse remotely with an opaque one — so most of these tests are about the
  rejections rather than the happy path.
  """

  use ExUnit.Case, async: true

  alias EDA.ImageData

  doctest EDA.ImageData

  # Real headers, so the detection is exercised against what a file actually starts with.
  @png <<0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A>> <> <<0, 0, 0, 13>>
  @jpeg <<0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10>>
  @gif87 "GIF87a" <> <<1, 0, 1, 0>>
  @gif89 "GIF89a" <> <<1, 0, 1, 0>>
  @webp "RIFF" <> <<36, 0, 0, 0>> <> "WEBPVP8 "

  describe "type/1" do
    test "identifies the three formats Discord accepts" do
      assert ImageData.type(@png) == {:ok, :png}
      assert ImageData.type(@jpeg) == {:ok, :jpeg}
      assert ImageData.type(@gif87) == {:ok, :gif}
      assert ImageData.type(@gif89) == {:ok, :gif}
    end

    test "singles WebP out, because that is the one people actually hit" do
      assert ImageData.type(@webp) == {:error, :webp}
    end

    test "a RIFF container that is not WebP is not mistaken for one" do
      wav = "RIFF" <> <<36, 0, 0, 0>> <> "WAVEfmt "
      assert ImageData.type(wav) == {:error, :unknown}
    end

    test "anything else is unknown rather than a crash" do
      assert ImageData.type("") == {:error, :unknown}
      assert ImageData.type("hello") == {:error, :unknown}
      assert ImageData.type(<<0, 1, 2, 3>>) == {:error, :unknown}
    end

    test "a truncated header is not a false positive" do
      assert ImageData.type(<<0x89, 0x50, 0x4E>>) == {:error, :unknown}
      assert ImageData.type("GIF8") == {:error, :unknown}
    end
  end

  describe "from_binary/1" do
    test "builds the data URI Discord documents" do
      assert ImageData.from_binary(@gif89) ==
               "data:image/gif;base64," <> Base.encode64(@gif89)

      assert ImageData.from_binary(@png) =~ ~r{^data:image/png;base64,}
      assert ImageData.from_binary(@jpeg) =~ ~r{^data:image/jpeg;base64,}
    end

    test "the media type follows the bytes, not any claim about them" do
      # A JPEG that someone named .png still gets image/jpeg.
      assert ImageData.from_binary(@jpeg) =~ "image/jpeg"
    end

    test "WebP is named in the error rather than left to Discord" do
      assert_raise ArgumentError, ~r/does not accept WebP/, fn ->
        ImageData.from_binary(@webp)
      end
    end

    test "an unrecognised binary says what was expected" do
      assert_raise ArgumentError, ~r/expected PNG, JPEG or GIF/, fn ->
        ImageData.from_binary("definitely not an image")
      end
    end
  end

  describe "from_binary/2" do
    test "states the format instead of detecting it" do
      assert ImageData.from_binary(<<1, 2, 3>>, :png) == "data:image/png;base64,AQID"
      assert ImageData.from_binary(<<1, 2, 3>>, :jpeg) == "data:image/jpeg;base64,AQID"
      assert ImageData.from_binary(<<1, 2, 3>>, :gif) == "data:image/gif;base64,AQID"
    end

    test "a format Discord has no media type for is rejected by name" do
      assert_raise ArgumentError, ~r/:webp is not an image data format/, fn ->
        ImageData.from_binary(<<1, 2, 3>>, :webp)
      end
    end
  end

  describe "from_path/1" do
    @tag :tmp_dir
    test "reads the file and detects from its contents", %{tmp_dir: tmp_dir} do
      path = Path.join(tmp_dir, "image.png")
      File.write!(path, @png)

      assert ImageData.from_path(path) == "data:image/png;base64," <> Base.encode64(@png)
    end

    @tag :tmp_dir
    test "the extension is not believed", %{tmp_dir: tmp_dir} do
      # JPEG bytes in a file called .png — the mistake this module exists to catch.
      path = Path.join(tmp_dir, "actually_a_jpeg.png")
      File.write!(path, @jpeg)

      assert ImageData.from_path(path) =~ "image/jpeg"
    end

    @tag :tmp_dir
    test "a WebP on disk fails here, not at the API", %{tmp_dir: tmp_dir} do
      path = Path.join(tmp_dir, "screenshot.webp")
      File.write!(path, @webp)

      assert_raise ArgumentError, ~r/does not accept WebP/, fn -> ImageData.from_path(path) end
    end

    test "a missing file says so" do
      assert_raise ArgumentError, ~r/image does not exist/, fn ->
        ImageData.from_path("/nonexistent/avatar.png")
      end
    end
  end

  describe "data_uri?/1" do
    test "recognises what it produces" do
      assert ImageData.data_uri?(ImageData.from_binary(@png))
      assert ImageData.data_uri?("data:image/gif;base64,AQID")
    end

    test "a path or an unrelated data URI is not one" do
      refute ImageData.data_uri?("avatar.png")
      refute ImageData.data_uri?("data:text/plain;base64,AQID")
      refute ImageData.data_uri?(nil)
      refute ImageData.data_uri?(123)
    end
  end

  describe "coerce/1" do
    test "nil passes through, because Discord reads it as 'clear this field'" do
      assert ImageData.coerce(nil) == nil
    end

    test "a data URI is left exactly as it was" do
      uri = "data:image/png;base64,AQID"
      assert ImageData.coerce(uri) == uri
    end

    test "raw image bytes are converted" do
      assert ImageData.coerce(@gif89) == "data:image/gif;base64," <> Base.encode64(@gif89)
    end

    @tag :tmp_dir
    test "a path is read from disk", %{tmp_dir: tmp_dir} do
      path = Path.join(tmp_dir, "a.png")
      File.write!(path, @png)

      assert ImageData.coerce(path) == "data:image/png;base64," <> Base.encode64(@png)
    end

    test "WebP bytes complain about WebP, not about a missing file" do
      # The naive reading would take these bytes for a filename.
      assert_raise ArgumentError, ~r/does not accept WebP/, fn -> ImageData.coerce(@webp) end
    end

    test "a long unrecognised binary is reported as image data, not as a path" do
      blob = :crypto.strong_rand_bytes(5_000)

      assert_raise ArgumentError, ~r/expected PNG, JPEG or GIF/, fn ->
        ImageData.coerce(blob)
      end
    end

    test "a short string that could be a filename is looked for on disk" do
      assert_raise ArgumentError, ~r/image does not exist/, fn ->
        ImageData.coerce("avatar.png")
      end
    end
  end
end
