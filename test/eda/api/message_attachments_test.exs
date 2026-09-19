defmodule EDA.API.MessageAttachmentsTest do
  @moduledoc """
  Covers what EDA puts on the wire for the `attachments` array of a message edit.

  Discord treats that array as the complete list the message should end up with, so what is
  *absent* from it matters as much as what is present. These tests assert the exact JSON,
  since an off-by-one in the retained entries silently deletes a user's attachments.

  The matching server-side behaviour was confirmed against the live API on 2026-09-19.
  """

  # NOT async — Bypass and the Application env are global.
  use ExUnit.Case

  alias EDA.API.Message
  alias EDA.Attachment

  setup do
    bypass = Bypass.open()
    Application.put_env(:eda, :base_url, "http://localhost:#{bypass.port}")
    Application.put_env(:eda, :token, "test-token")

    on_exit(fn -> Application.delete_env(:eda, :base_url) end)

    {:ok, bypass: bypass}
  end

  defp expect_patch(bypass, test_pid) do
    Bypass.expect_once(bypass, "PATCH", "/channels/111/messages/222", fn conn ->
      {:ok, raw, conn} = Plug.Conn.read_body(conn)
      send(test_pid, {:body, raw, Plug.Conn.get_req_header(conn, "content-type")})

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.resp(200, Jason.encode!(%{"id" => "222", "attachments" => []}))
    end)
  end

  describe "the :attachments option on a JSON edit" do
    test "retained ids are sent as the whole array", %{bypass: bypass} do
      expect_patch(bypass, self())

      assert {:ok, _} =
               Message.edit("111", "222",
                 content: "edited",
                 attachments: [Attachment.keep("900"), Attachment.keep("901")]
               )

      assert_receive {:body, raw, _ct}
      body = Jason.decode!(raw)

      assert body["content"] == "edited"
      assert body["attachments"] == [%{"id" => "900"}, %{"id" => "901"}]
    end

    test "structs, raw maps and bare ids all normalise to an id entry", %{bypass: bypass} do
      expect_patch(bypass, self())

      assert {:ok, _} =
               Message.edit("111", "222",
                 attachments: [
                   %Attachment{id: "1", filename: "a.png", description: "dropped"},
                   %{"id" => "2", "filename" => "b.png"},
                   "3",
                   4
                 ]
               )

      assert_receive {:body, raw, _ct}

      assert Jason.decode!(raw)["attachments"] == [
               %{"id" => "1"},
               %{"id" => "2"},
               %{"id" => "3"},
               %{"id" => 4}
             ]
    end

    test "a keep/2 map passes through untouched", %{bypass: bypass} do
      expect_patch(bypass, self())

      assert {:ok, _} =
               Message.edit("111", "222",
                 attachments: [Attachment.keep("900", is_spoiler: true, description: "Alt")]
               )

      assert_receive {:body, raw, _ct}

      assert Jason.decode!(raw)["attachments"] ==
               [%{"id" => "900", "is_spoiler" => true, "description" => "Alt"}]
    end

    test "an empty list is sent as an empty array — it strips every attachment",
         %{bypass: bypass} do
      expect_patch(bypass, self())

      assert {:ok, _} = Message.edit("111", "222", attachments: [])

      assert_receive {:body, raw, _ct}
      assert Jason.decode!(raw)["attachments"] == []
    end

    test "omitting the option sends no array at all, which changes nothing",
         %{bypass: bypass} do
      expect_patch(bypass, self())

      assert {:ok, _} = Message.edit("111", "222", content: "just the text")

      assert_receive {:body, raw, _ct}
      refute Map.has_key?(Jason.decode!(raw), "attachments")
    end

    test "a value that is not an attachment is rejected before any request", %{bypass: bypass} do
      Bypass.down(bypass)

      assert_raise ArgumentError, ~r/attachment must be/, fn ->
        Message.edit("111", "222", attachments: [:nope])
      end

      assert_raise ArgumentError, ~r/:attachments must be a list/, fn ->
        Message.edit("111", "222", attachments: %{id: "1"})
      end
    end
  end

  describe "the :attachments option alongside an upload" do
    test "retained entries come first and the file is indexed from zero",
         %{bypass: bypass} do
      expect_patch(bypass, self())

      assert {:ok, _} =
               Message.edit("111", "222",
                 attachments: [Attachment.keep("900")],
                 files: [EDA.File.from_binary("x", "new.png", spoiler: true)]
               )

      assert_receive {:body, raw, [content_type]}
      assert content_type =~ "multipart/form-data"

      payload = extract_json_payload(raw)

      assert payload["attachments"] == [
               %{"id" => "900"},
               %{"id" => 0, "filename" => "new.png", "is_spoiler" => true}
             ]
    end
  end

  describe "EDA.Message.edit/2 with attachments: :keep" do
    test "expands to the attachments the struct already holds", %{bypass: bypass} do
      expect_patch(bypass, self())

      message = %EDA.Message{
        channel_id: "111",
        id: "222",
        attachments: [%Attachment{id: "900"}, %Attachment{id: "901"}]
      }

      assert {:ok, _} = EDA.Message.edit(message, content: "hi", attachments: :keep)

      assert_receive {:body, raw, _ct}
      assert Jason.decode!(raw)["attachments"] == [%{"id" => "900"}, %{"id" => "901"}]
    end

    test "a message with no attachments sends no array, rather than an empty one",
         %{bypass: bypass} do
      expect_patch(bypass, self())

      message = %EDA.Message{channel_id: "111", id: "222", attachments: []}

      assert {:ok, _} = EDA.Message.edit(message, content: "hi", attachments: :keep)

      assert_receive {:body, raw, _ct}
      refute Map.has_key?(Jason.decode!(raw), "attachments")
    end

    test "attachments never parsed from the payload are treated the same", %{bypass: bypass} do
      expect_patch(bypass, self())

      message = %EDA.Message{channel_id: "111", id: "222", attachments: nil}

      assert {:ok, _} = EDA.Message.edit(message, attachments: :keep)

      assert_receive {:body, raw, _ct}
      refute Map.has_key?(Jason.decode!(raw), "attachments")
    end

    test "an explicit list is passed through instead of being expanded", %{bypass: bypass} do
      expect_patch(bypass, self())

      message = %EDA.Message{
        channel_id: "111",
        id: "222",
        attachments: [%Attachment{id: "900"}, %Attachment{id: "901"}]
      }

      assert {:ok, _} =
               EDA.Message.edit(message,
                 attachments: [Attachment.keep("901", is_spoiler: true)]
               )

      assert_receive {:body, raw, _ct}
      assert Jason.decode!(raw)["attachments"] == [%{"id" => "901", "is_spoiler" => true}]
    end

    test "the map form still works and is left alone", %{bypass: bypass} do
      expect_patch(bypass, self())

      message = %EDA.Message{channel_id: "111", id: "222", attachments: [%Attachment{id: "9"}]}

      assert {:ok, _} = EDA.Message.edit(message, %{content: "raw payload"})

      assert_receive {:body, raw, _ct}
      body = Jason.decode!(raw)
      assert body["content"] == "raw payload"
      refute Map.has_key?(body, "attachments")
    end
  end

  defp extract_json_payload(body) do
    [_, json] = Regex.run(~r/name="payload_json".*?\r\n\r\n(.*?)\r\n--/s, body)
    Jason.decode!(json)
  end
end
