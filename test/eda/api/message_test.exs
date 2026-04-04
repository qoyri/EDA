defmodule EDA.API.MessageTest do
  use ExUnit.Case

  alias EDA.API.Message

  setup do
    bypass = Bypass.open()
    Application.put_env(:eda, :base_url, "http://localhost:#{bypass.port}")
    Application.put_env(:eda, :token, "test-token")

    on_exit(fn ->
      Application.delete_env(:eda, :base_url)
    end)

    {:ok, bypass: bypass}
  end

  # ── Helpers ──────────────────────────────────────────────────────────

  defp json(conn, body, status \\ 200) do
    conn
    |> Plug.Conn.put_resp_content_type("application/json")
    |> Plug.Conn.resp(status, Jason.encode!(body))
  end

  defp assert_auth_header(conn) do
    assert Plug.Conn.get_req_header(conn, "authorization") == ["Bot test-token"]
    conn
  end

  defp read_json_body(conn) do
    {:ok, raw, conn} = Plug.Conn.read_body(conn)
    {Jason.decode!(raw), conn}
  end

  # ── get_message ────────────────────────────────────────────────────

  describe "get/2" do
    test "GET /channels/:id/messages/:id", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/channels/111/messages/222", fn conn ->
        conn |> assert_auth_header() |> json(%{"id" => "222", "content" => "hi"})
      end)

      assert {:ok, %{"id" => "222"}} = Message.get("111", "222")
    end
  end

  # ── get_messages ───────────────────────────────────────────────────

  describe "list/2" do
    test "GET /channels/:id/messages without opts", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/channels/111/messages", fn conn ->
        conn |> assert_auth_header() |> json([%{"id" => "1"}])
      end)

      assert {:ok, [%{"id" => "1"}]} = Message.list("111")
    end

    test "GET /channels/:id/messages with query params", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/channels/111/messages", fn conn ->
        conn = Plug.Conn.fetch_query_params(conn)
        assert conn.query_params["limit"] == "50"
        assert conn.query_params["before"] == "999"
        json(conn, [])
      end)

      assert {:ok, []} = Message.list("111", limit: 50, before: "999")
    end

    test "nil opts are filtered out", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/channels/111/messages", fn conn ->
        conn = Plug.Conn.fetch_query_params(conn)
        assert conn.query_params == %{"limit" => "10"}
        json(conn, [])
      end)

      assert {:ok, []} = Message.list("111", limit: 10, before: nil)
    end
  end

  # ── create_message ─────────────────────────────────────────────────

  describe "create/2" do
    test "string content", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/channels/111/messages", fn conn ->
        {body, conn} = read_json_body(conn)
        assert body["content"] == "hello"
        json(conn, %{"id" => "1", "content" => "hello"})
      end)

      assert {:ok, %{"content" => "hello"}} = Message.create("111", "hello")
    end

    test "map payload", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/channels/111/messages", fn conn ->
        {body, conn} = read_json_body(conn)
        assert body["content"] == "test"
        json(conn, %{"id" => "1", "content" => "test"})
      end)

      assert {:ok, _} = Message.create("111", %{content: "test"})
    end
  end

  # ── edit_message ───────────────────────────────────────────────────

  describe "edit/3" do
    test "PATCH /channels/:id/messages/:id", %{bypass: bypass} do
      Bypass.expect_once(bypass, "PATCH", "/channels/111/messages/222", fn conn ->
        {body, conn} = read_json_body(conn)
        assert body["content"] == "edited"
        json(conn, %{"id" => "222", "content" => "edited"})
      end)

      assert {:ok, %{"content" => "edited"}} =
               Message.edit("111", "222", %{content: "edited"})
    end
  end

  # ── delete_message ─────────────────────────────────────────────────

  describe "delete/2" do
    test "DELETE /channels/:id/messages/:id", %{bypass: bypass} do
      Bypass.expect_once(bypass, "DELETE", "/channels/111/messages/222", fn conn ->
        Plug.Conn.resp(conn, 204, "")
      end)

      assert :ok = Message.delete("111", "222")
    end
  end

  # ── bulk_delete_messages ───────────────────────────────────────────

  describe "bulk_delete/2" do
    test "POST /channels/:id/messages/bulk-delete", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/channels/111/messages/bulk-delete", fn conn ->
        {body, conn} = read_json_body(conn)
        assert body["messages"] == ["1", "2", "3"]
        Plug.Conn.resp(conn, 204, "")
      end)

      assert :ok = Message.bulk_delete("111", ["1", "2", "3"])
    end
  end

  # ── Pins ───────────────────────────────────────────────────────────

  describe "pinned/1" do
    test "GET /channels/:id/pins", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/channels/111/pins", fn conn ->
        json(conn, [%{"id" => "1"}])
      end)

      assert {:ok, [%{"id" => "1"}]} = Message.pinned("111")
    end
  end

  describe "pin/2" do
    test "PUT /channels/:id/pins/:id", %{bypass: bypass} do
      Bypass.expect_once(bypass, "PUT", "/channels/111/pins/222", fn conn ->
        Plug.Conn.resp(conn, 204, "")
      end)

      assert :ok = Message.pin("111", "222")
    end
  end

  describe "unpin/2" do
    test "DELETE /channels/:id/pins/:id", %{bypass: bypass} do
      Bypass.expect_once(bypass, "DELETE", "/channels/111/pins/222", fn conn ->
        Plug.Conn.resp(conn, 204, "")
      end)

      assert :ok = Message.unpin("111", "222")
    end
  end

  # ── Message History (pagination) ───────────────────────────────────

  describe "history/3" do
    test "returns a single page when limit <= 100", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/channels/111/messages", fn conn ->
        conn = Plug.Conn.fetch_query_params(conn)
        assert conn.query_params["limit"] == "50"
        json(conn, Enum.map(1..50, &%{"id" => to_string(&1)}))
      end)

      assert {:ok, msgs} = Message.history("111", 50)
      assert length(msgs) == 50
    end

    test "auto-paginates when limit > 100", %{bypass: bypass} do
      call_count = :counters.new(1, [])

      Bypass.expect(bypass, "GET", "/channels/111/messages", fn conn ->
        :counters.add(call_count, 1, 1)
        count = :counters.get(call_count, 1)
        conn = Plug.Conn.fetch_query_params(conn)

        case count do
          1 ->
            assert conn.query_params["limit"] == "100"
            # IDs 199..100, last is "100"
            json(conn, Enum.map(1..100, &%{"id" => to_string(200 - &1)}))

          2 ->
            assert conn.query_params["limit"] == "100"
            assert conn.query_params["before"] == "100"
            json(conn, Enum.map(1..50, &%{"id" => to_string(100 - &1)}))
        end
      end)

      assert {:ok, msgs} = Message.history("111", 200)
      assert length(msgs) == 150
    end

    test ":infinity paginates until empty page", %{bypass: bypass} do
      call_count = :counters.new(1, [])

      Bypass.expect(bypass, "GET", "/channels/111/messages", fn conn ->
        :counters.add(call_count, 1, 1)
        count = :counters.get(call_count, 1)

        case count do
          1 -> json(conn, Enum.map(1..100, &%{"id" => to_string(200 - &1)}))
          2 -> json(conn, Enum.map(1..100, &%{"id" => to_string(100 - &1)}))
          3 -> json(conn, [])
        end
      end)

      assert {:ok, msgs} = Message.history("111", :infinity)
      assert length(msgs) == 200
    end

    test ":around does not paginate", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/channels/111/messages", fn conn ->
        conn = Plug.Conn.fetch_query_params(conn)
        assert conn.query_params["around"] == "500"
        assert conn.query_params["limit"] == "50"
        json(conn, Enum.map(1..50, &%{"id" => to_string(&1)}))
      end)

      assert {:ok, msgs} = Message.history("111", 50, around: "500")
      assert length(msgs) == 50
    end

    test ":before passes cursor correctly", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/channels/111/messages", fn conn ->
        conn = Plug.Conn.fetch_query_params(conn)
        assert conn.query_params["before"] == "999"
        json(conn, [%{"id" => "998"}])
      end)

      assert {:ok, [%{"id" => "998"}]} = Message.history("111", 10, before: "999")
    end

    test ":after passes cursor correctly", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/channels/111/messages", fn conn ->
        conn = Plug.Conn.fetch_query_params(conn)
        assert conn.query_params["after"] == "100"
        json(conn, [%{"id" => "101"}])
      end)

      assert {:ok, [%{"id" => "101"}]} = Message.history("111", 10, after: "100")
    end

    test "error on first page returns error", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/channels/111/messages", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(403, Jason.encode!(%{"message" => "Missing Access", "code" => 50_001}))
      end)

      assert {:error, _} = Message.history("111", 50)
    end

    test "error on subsequent page returns already-collected messages", %{bypass: bypass} do
      call_count = :counters.new(1, [])

      Bypass.expect(bypass, "GET", "/channels/111/messages", fn conn ->
        :counters.add(call_count, 1, 1)
        count = :counters.get(call_count, 1)

        case count do
          1 ->
            json(conn, Enum.map(1..100, &%{"id" => to_string(200 - &1)}))

          2 ->
            conn
            |> Plug.Conn.put_resp_content_type("application/json")
            |> Plug.Conn.resp(500, Jason.encode!(%{"message" => "Server Error", "code" => 0}))
        end
      end)

      assert {:ok, msgs} = Message.history("111", 200)
      assert length(msgs) == 100
    end
  end

  # ── Message Stream ─────────────────────────────────────────────────

  describe "stream/2" do
    test "Stream.take(50) fetches only one page", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/channels/111/messages", fn conn ->
        conn = Plug.Conn.fetch_query_params(conn)
        assert conn.query_params["limit"] == "100"
        json(conn, Enum.map(1..100, &%{"id" => to_string(&1)}))
      end)

      msgs = Message.stream("111") |> Stream.take(50) |> Enum.to_list()
      assert length(msgs) == 50
    end

    test "stream iterates multiple pages", %{bypass: bypass} do
      call_count = :counters.new(1, [])

      Bypass.expect(bypass, "GET", "/channels/111/messages", fn conn ->
        :counters.add(call_count, 1, 1)
        count = :counters.get(call_count, 1)

        case count do
          1 -> json(conn, Enum.map(1..100, &%{"id" => to_string(200 - &1)}))
          2 -> json(conn, Enum.map(1..50, &%{"id" => to_string(100 - &1)}))
          3 -> json(conn, [])
        end
      end)

      msgs = Message.stream("111") |> Enum.to_list()
      assert length(msgs) == 150
    end

    test "stream stops on empty page", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/channels/111/messages", fn conn ->
        json(conn, [])
      end)

      msgs = Message.stream("111") |> Enum.to_list()
      assert msgs == []
    end
  end

  # ── Purge Messages ─────────────────────────────────────────────────

  describe "purge/2" do
    test "purge simple (< 100 messages)", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/channels/111/messages", fn conn ->
        now_snowflake = EDA.Snowflake.from_datetime(DateTime.utc_now())
        msgs = Enum.map(0..9, &%{"id" => to_string(now_snowflake - &1)})
        json(conn, msgs)
      end)

      Bypass.expect_once(bypass, "POST", "/channels/111/messages/bulk-delete", fn conn ->
        {body, conn} = read_json_body(conn)
        assert length(body["messages"]) == 10
        Plug.Conn.resp(conn, 204, "")
      end)

      assert {:ok, 10} = Message.purge("111", limit: 10)
    end

    test "purge with auto-chunk (> 100 messages)", %{bypass: bypass} do
      now_snowflake = EDA.Snowflake.from_datetime(DateTime.utc_now())

      Bypass.expect_once(bypass, "GET", "/channels/111/messages", fn conn ->
        msgs = Enum.map(0..149, &%{"id" => to_string(now_snowflake - &1)})
        json(conn, msgs)
      end)

      bulk_count = :counters.new(1, [])

      Bypass.expect(bypass, "POST", "/channels/111/messages/bulk-delete", fn conn ->
        :counters.add(bulk_count, 1, 1)
        {body, conn} = read_json_body(conn)
        count = :counters.get(bulk_count, 1)

        case count do
          1 -> assert length(body["messages"]) == 100
          2 -> assert length(body["messages"]) == 50
        end

        Plug.Conn.resp(conn, 204, "")
      end)

      assert {:ok, 150} = Message.purge("111", limit: 150)
      assert :counters.get(bulk_count, 1) == 2
    end

    test "filter by predicate works", %{bypass: bypass} do
      now_snowflake = EDA.Snowflake.from_datetime(DateTime.utc_now())

      Bypass.expect_once(bypass, "GET", "/channels/111/messages", fn conn ->
        msgs = [
          %{"id" => to_string(now_snowflake), "author" => %{"id" => "user1"}},
          %{"id" => to_string(now_snowflake - 1), "author" => %{"id" => "user2"}},
          %{"id" => to_string(now_snowflake - 2), "author" => %{"id" => "user1"}}
        ]

        json(conn, msgs)
      end)

      Bypass.expect_once(bypass, "POST", "/channels/111/messages/bulk-delete", fn conn ->
        {body, conn} = read_json_body(conn)
        assert length(body["messages"]) == 2
        Plug.Conn.resp(conn, 204, "")
      end)

      assert {:ok, 2} =
               Message.purge("111",
                 limit: 10,
                 filter: fn msg -> msg["author"]["id"] == "user1" end
               )
    end

    test "filter_old excludes messages older than 14 days", %{bypass: bypass} do
      now_snowflake = EDA.Snowflake.from_datetime(DateTime.utc_now())
      old_snowflake = EDA.Snowflake.from_datetime(DateTime.add(DateTime.utc_now(), -15, :day))

      Bypass.expect_once(bypass, "GET", "/channels/111/messages", fn conn ->
        msgs = [
          %{"id" => to_string(now_snowflake)},
          %{"id" => to_string(old_snowflake)}
        ]

        json(conn, msgs)
      end)

      Bypass.expect_once(bypass, "POST", "/channels/111/messages/bulk-delete", fn conn ->
        {body, conn} = read_json_body(conn)
        assert length(body["messages"]) == 1
        Plug.Conn.resp(conn, 204, "")
      end)

      assert {:ok, 1} = Message.purge("111", limit: 10)
    end

    test "filter_old: false keeps old messages", %{bypass: bypass} do
      now_snowflake = EDA.Snowflake.from_datetime(DateTime.utc_now())
      old_snowflake = EDA.Snowflake.from_datetime(DateTime.add(DateTime.utc_now(), -15, :day))

      Bypass.expect_once(bypass, "GET", "/channels/111/messages", fn conn ->
        msgs = [
          %{"id" => to_string(now_snowflake)},
          %{"id" => to_string(old_snowflake)}
        ]

        json(conn, msgs)
      end)

      Bypass.expect_once(bypass, "POST", "/channels/111/messages/bulk-delete", fn conn ->
        {body, conn} = read_json_body(conn)
        assert length(body["messages"]) == 2
        Plug.Conn.resp(conn, 204, "")
      end)

      assert {:ok, 2} = Message.purge("111", limit: 10, filter_old: false)
    end
  end

  # ── File Uploads (Multipart) ───────────────────────────────────────

  describe "create/2 with files" do
    test "sends multipart when :files option present", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/channels/111/messages", fn conn ->
        assert_multipart_request(conn)
      end)

      file = EDA.File.from_binary("hello", "test.txt")
      assert {:ok, _} = Message.create("111", content: "hi", files: [file])
    end

    test "sends multipart with single :file option", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/channels/111/messages", fn conn ->
        assert_multipart_request(conn)
      end)

      file = EDA.File.from_binary("data", "img.png")
      assert {:ok, _} = Message.create("111", content: "look", file: file)
    end

    test "sends multipart with tuple shorthand", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/channels/111/messages", fn conn ->
        assert_multipart_request(conn)
      end)

      assert {:ok, _} = Message.create("111", content: "hi", files: [{"data", "test.txt"}])
    end

    test "still sends JSON when no files", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/channels/111/messages", fn conn ->
        [content_type] = Plug.Conn.get_req_header(conn, "content-type")
        assert content_type == "application/json"
        json(conn, %{"id" => "1"})
      end)

      assert {:ok, _} = Message.create("111", content: "no files")
    end
  end

  describe "edit/3 with files" do
    test "sends multipart when :files option present", %{bypass: bypass} do
      Bypass.expect_once(bypass, "PATCH", "/channels/111/messages/222", fn conn ->
        assert_multipart_request(conn)
      end)

      file = EDA.File.from_binary("new", "update.txt")
      assert {:ok, _} = Message.edit("111", "222", content: "edited", files: [file])
    end
  end

  # ── forward ───────────────────────────────────────────────────────

  describe "forward/3" do
    test "POST with message_reference type 1", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/channels/999/messages", fn conn ->
        {:ok, raw, conn} = Plug.Conn.read_body(conn)
        body = Jason.decode!(raw)
        assert body["message_reference"]["type"] == 1
        assert body["message_reference"]["channel_id"] == "111"
        assert body["message_reference"]["message_id"] == "222"
        json(conn, %{"id" => "333", "type" => 0})
      end)

      assert {:ok, %{"id" => "333"}} = Message.forward("999", "111", "222")
    end
  end

  # ── reply ─────────────────────────────────────────────────────────

  describe "reply/2" do
    test "adds message_reference with struct-style message", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/channels/111/messages", fn conn ->
        {:ok, raw, conn} = Plug.Conn.read_body(conn)
        body = Jason.decode!(raw)
        assert body["content"] == "Got it!"
        assert body["message_reference"]["message_id"] == "222"
        json(conn, %{"id" => "333"})
      end)

      msg = %{channel_id: "111", id: "222"}
      assert {:ok, _} = Message.reply(msg, "Got it!")
    end

    test "adds message_reference with raw map message", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/channels/111/messages", fn conn ->
        {:ok, raw, conn} = Plug.Conn.read_body(conn)
        body = Jason.decode!(raw)
        assert body["message_reference"]["message_id"] == "222"
        json(conn, %{"id" => "333"})
      end)

      msg = %{"channel_id" => "111", "id" => "222"}
      assert {:ok, _} = Message.reply(msg, "Reply!")
    end

    test "reply with keyword opts", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/channels/111/messages", fn conn ->
        {:ok, raw, conn} = Plug.Conn.read_body(conn)
        body = Jason.decode!(raw)
        assert body["content"] == "With embed"
        assert body["message_reference"]["message_id"] == "222"
        json(conn, %{"id" => "333"})
      end)

      msg = %{channel_id: "111", id: "222"}
      assert {:ok, _} = Message.reply(msg, content: "With embed")
    end
  end

  defp assert_multipart_request(conn) do
    [content_type] = Plug.Conn.get_req_header(conn, "content-type")
    assert content_type =~ "multipart/form-data; boundary="

    {:ok, raw, conn} = Plug.Conn.read_body(conn)
    assert raw =~ "payload_json"
    assert raw =~ "files[0]"
    json(conn, %{"id" => "1"})
  end
end
