defmodule EDA.HTTP.MultipartTest do
  use ExUnit.Case, async: true

  alias EDA.HTTP.Multipart
  alias EDA.File, as: F

  describe "encode/2" do
    test "produces valid multipart body with boundary" do
      file = F.from_binary("hello", "test.txt")
      {body_iodata, content_type} = Multipart.encode(%{content: "hi"}, [file])

      body = IO.iodata_to_binary(body_iodata)

      assert content_type =~ "multipart/form-data; boundary="
      boundary = String.replace_prefix(content_type, "multipart/form-data; boundary=", "")

      assert body =~ "--#{boundary}"
      assert body =~ "--#{boundary}--"
    end

    test "includes payload_json part with attachments array" do
      file = F.from_binary("data", "image.png", description: "Alt text")
      {body_iodata, _ct} = Multipart.encode(%{content: "look"}, [file])

      body = IO.iodata_to_binary(body_iodata)

      assert body =~ "payload_json"
      assert body =~ "application/json"

      # Extract JSON from payload_json part
      json_part = extract_json_payload(body)
      assert json_part["content"] == "look"
      assert length(json_part["attachments"]) == 1

      [att] = json_part["attachments"]
      assert att["id"] == 0
      assert att["filename"] == "image.png"
      assert att["description"] == "Alt text"
    end

    test "multiple files are indexed correctly" do
      files = [
        F.from_binary("aaa", "a.txt"),
        F.from_binary("bbb", "b.png")
      ]

      {body_iodata, _ct} = Multipart.encode(%{}, files)
      body = IO.iodata_to_binary(body_iodata)

      assert body =~ ~s(name="files[0]")
      assert body =~ ~s(filename="a.txt")
      assert body =~ ~s(name="files[1]")
      assert body =~ ~s(filename="b.png")

      json_part = extract_json_payload(body)
      assert length(json_part["attachments"]) == 2
      assert Enum.at(json_part["attachments"], 0)["id"] == 0
      assert Enum.at(json_part["attachments"], 1)["id"] == 1
    end

    test "a spoiler is requested with is_spoiler, leaving the filename alone" do
      file = F.from_binary("data", "secret.png", spoiler: true)
      {body_iodata, _ct} = Multipart.encode(%{}, [file])

      body = IO.iodata_to_binary(body_iodata)
      assert body =~ ~s(filename="secret.png")
      refute body =~ "SPOILER_"

      json_part = extract_json_payload(body)
      [att] = json_part["attachments"]
      assert att["filename"] == "secret.png"
      assert att["is_spoiler"] == true
    end

    test "a file that is not a spoiler says nothing about it" do
      file = F.from_binary("data", "plain.png")
      {body_iodata, _ct} = Multipart.encode(%{}, [file])

      [att] =
        body_iodata |> IO.iodata_to_binary() |> extract_json_payload() |> Map.get("attachments")

      refute Map.has_key?(att, "is_spoiler")
    end

    test "a filename the caller prefixed itself is left untouched" do
      file = F.from_binary("data", "SPOILER_manual.png")
      {body_iodata, _ct} = Multipart.encode(%{}, [file])

      body = IO.iodata_to_binary(body_iodata)
      assert body =~ ~s(filename="SPOILER_manual.png")
    end

    test "attachments already in the payload are kept, and uploads indexed after them" do
      # An edit that retains two attachments and adds one file. Dropping the retained
      # entries would delete those two attachments from the message.
      payload = %{
        content: "edited",
        attachments: [%{id: "111"}, %{id: "222", is_spoiler: true}]
      }

      {body_iodata, _ct} = Multipart.encode(payload, [F.from_binary("x", "new.png")])
      json_part = body_iodata |> IO.iodata_to_binary() |> extract_json_payload()

      assert [first, second, third] = json_part["attachments"]
      assert first["id"] == "111"
      assert second["id"] == "222"
      assert second["is_spoiler"] == true
      # a new file is addressed by its index in files[n], not by a snowflake
      assert third["id"] == 0
      assert third["filename"] == "new.png"
    end

    test "a string-keyed attachments array is honoured too" do
      {body_iodata, _ct} = Multipart.encode(%{"attachments" => [%{"id" => "9"}]}, [])
      json_part = body_iodata |> IO.iodata_to_binary() |> extract_json_payload()

      assert [%{"id" => "9"}] = json_part["attachments"]
    end

    test "no files and nothing retained never sends an empty array" do
      # An empty attachments array deletes every attachment on the message being edited.
      {body_iodata, _ct} = Multipart.encode(%{content: "hi"}, [])
      json_part = body_iodata |> IO.iodata_to_binary() |> extract_json_payload()

      refute Map.has_key?(json_part, "attachments")
    end

    test "a non-list attachments value is rejected" do
      assert_raise ArgumentError, ~r/attachments must be a list/, fn ->
        Multipart.encode(%{attachments: %{id: "1"}}, [])
      end
    end

    test "file data is included in body" do
      file = F.from_binary("binary content here", "doc.txt")
      {body_iodata, _ct} = Multipart.encode(%{}, [file])

      body = IO.iodata_to_binary(body_iodata)
      assert body =~ "binary content here"
    end
  end

  describe "mime_type/1" do
    test "common image types" do
      assert Multipart.mime_type("photo.png") == "image/png"
      assert Multipart.mime_type("photo.jpg") == "image/jpeg"
      assert Multipart.mime_type("photo.jpeg") == "image/jpeg"
      assert Multipart.mime_type("anim.gif") == "image/gif"
      assert Multipart.mime_type("sticker.webp") == "image/webp"
    end

    test "audio types" do
      assert Multipart.mime_type("song.mp3") == "audio/mpeg"
      assert Multipart.mime_type("voice.ogg") == "audio/ogg"
    end

    test "video types" do
      assert Multipart.mime_type("clip.mp4") == "video/mp4"
      assert Multipart.mime_type("clip.webm") == "video/webm"
    end

    test "other types" do
      assert Multipart.mime_type("doc.pdf") == "application/pdf"
      assert Multipart.mime_type("notes.txt") == "text/plain"
      assert Multipart.mime_type("archive.zip") == "application/zip"
    end

    test "unknown extension falls back to octet-stream" do
      assert Multipart.mime_type("file.xyz") == "application/octet-stream"
      assert Multipart.mime_type("noext") == "application/octet-stream"
    end

    test "case insensitive" do
      assert Multipart.mime_type("IMAGE.PNG") == "image/png"
      assert Multipart.mime_type("Song.MP3") == "audio/mpeg"
    end
  end

  describe "escape_filename/1" do
    test "escapes double quotes" do
      assert Multipart.escape_filename(~s(file"name.txt)) == ~s(file\\"name.txt)
    end

    test "escapes backslashes" do
      assert Multipart.escape_filename("file\\name.txt") == "file\\\\name.txt"
    end

    test "replaces newlines with underscores" do
      assert Multipart.escape_filename("file\nname.txt") == "file_name.txt"
      assert Multipart.escape_filename("file\r\nname.txt") == "file__name.txt"
    end

    test "handles combined special characters" do
      assert Multipart.escape_filename("a\"b\\c\nd.txt") == "a\\\"b\\\\c_d.txt"
    end

    test "passes through normal filenames unchanged" do
      assert Multipart.escape_filename("normal-file_123.png") == "normal-file_123.png"
    end
  end

  # Helper to extract the JSON payload from the multipart body
  defp extract_json_payload(body) do
    # Find the payload_json part and extract the JSON
    [_, after_disposition] = String.split(body, ~s(name="payload_json"), parts: 2)
    # Skip past the Content-Type header and blank line
    [_, json_and_rest] = String.split(after_disposition, "\r\n\r\n", parts: 2)
    # Take until the next boundary
    [json_str | _] = String.split(json_and_rest, "\r\n--", parts: 2)
    Jason.decode!(json_str)
  end
end
