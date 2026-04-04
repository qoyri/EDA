defmodule EDA.API.ThreadTest do
  use ExUnit.Case

  alias EDA.API.Thread

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

  defp read_json_body(conn) do
    {:ok, raw, conn} = Plug.Conn.read_body(conn)
    {Jason.decode!(raw), conn}
  end

  # ── start_thread_from_message ──────────────────────────────────────

  describe "start_from_message/3" do
    test "POST /channels/:id/messages/:id/threads", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/channels/111/messages/222/threads", fn conn ->
        {body, conn} = read_json_body(conn)
        assert body["name"] == "my thread"
        json(conn, %{"id" => "333", "name" => "my thread"})
      end)

      assert {:ok, %{"name" => "my thread"}} =
               Thread.start_from_message("111", "222", %{name: "my thread"})
    end
  end

  # ── start_thread ───────────────────────────────────────────────────

  describe "start/2" do
    test "POST /channels/:id/threads", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/channels/111/threads", fn conn ->
        {body, conn} = read_json_body(conn)
        assert body["name"] == "thread"
        assert body["type"] == 11
        json(conn, %{"id" => "333", "name" => "thread"})
      end)

      assert {:ok, _} = Thread.start("111", %{name: "thread", type: 11})
    end
  end

  # ── join_thread ────────────────────────────────────────────────────

  describe "join/1" do
    test "PUT /channels/:id/thread-members/@me", %{bypass: bypass} do
      Bypass.expect_once(bypass, "PUT", "/channels/111/thread-members/@me", fn conn ->
        Plug.Conn.resp(conn, 204, "")
      end)

      assert :ok = Thread.join("111")
    end
  end

  # ── leave_thread ───────────────────────────────────────────────────

  describe "leave/1" do
    test "DELETE /channels/:id/thread-members/@me", %{bypass: bypass} do
      Bypass.expect_once(bypass, "DELETE", "/channels/111/thread-members/@me", fn conn ->
        Plug.Conn.resp(conn, 204, "")
      end)

      assert :ok = Thread.leave("111")
    end
  end

  # ── add_thread_member ──────────────────────────────────────────────

  describe "add_member/2" do
    test "PUT /channels/:id/thread-members/:id", %{bypass: bypass} do
      Bypass.expect_once(bypass, "PUT", "/channels/111/thread-members/222", fn conn ->
        Plug.Conn.resp(conn, 204, "")
      end)

      assert :ok = Thread.add_member("111", "222")
    end
  end

  # ── list_active_threads ────────────────────────────────────────────

  describe "list_active/1" do
    test "GET /guilds/:id/threads/active", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/guilds/111/threads/active", fn conn ->
        json(conn, %{"threads" => [], "members" => []})
      end)

      assert {:ok, %{"threads" => []}} = Thread.list_active("111")
    end
  end

  # ── create_post (forum) ──────────────────────────────────────────

  describe "create_post/3" do
    test "sends correct JSON body without files", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/channels/111/threads", fn conn ->
        {body, conn} = read_json_body(conn)
        assert body["name"] == "My Post"
        assert body["message"]["content"] == "Hello forum!"
        json(conn, %{"id" => "444", "name" => "My Post"})
      end)

      assert {:ok, %{"name" => "My Post"}} =
               Thread.create_post("111", [name: "My Post"], content: "Hello forum!")
    end

    test "includes applied_tags in the body", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/channels/111/threads", fn conn ->
        {body, conn} = read_json_body(conn)
        assert body["applied_tags"] == ["t1", "t2"]
        assert body["name"] == "Tagged Post"
        json(conn, %{"id" => "555"})
      end)

      assert {:ok, _} =
               Thread.create_post(
                 "111",
                 [name: "Tagged Post", applied_tags: ["t1", "t2"]],
                 content: "content"
               )
    end

    test "sends multipart request with files", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/channels/111/threads", fn conn ->
        # Multipart requests have a different content-type
        [content_type] =
          Plug.Conn.get_req_header(conn, "content-type")

        assert content_type =~ "multipart/form-data"
        json(conn, %{"id" => "666", "name" => "File Post"})
      end)

      assert {:ok, _} =
               Thread.create_post(
                 "111",
                 [name: "File Post"],
                 content: "See file",
                 file: {"hello", "test.txt"}
               )
    end

    test "includes optional thread fields", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/channels/111/threads", fn conn ->
        {body, conn} = read_json_body(conn)
        assert body["auto_archive_duration"] == 1440
        assert body["rate_limit_per_user"] == 60
        json(conn, %{"id" => "777"})
      end)

      assert {:ok, _} =
               Thread.create_post(
                 "111",
                 [name: "Configured", auto_archive_duration: 1440, rate_limit_per_user: 60],
                 content: "hello"
               )
    end
  end

  # ── remove_thread_member ─────────────────────────────────────────────

  describe "remove_member/2" do
    test "DELETE /channels/:id/thread-members/:user_id", %{bypass: bypass} do
      Bypass.expect_once(bypass, "DELETE", "/channels/111/thread-members/222", fn conn ->
        Plug.Conn.resp(conn, 204, "")
      end)

      assert :ok = Thread.remove_member("111", "222")
    end
  end

  # ── get_thread_member ────────────────────────────────────────────────

  describe "get_member/2" do
    test "GET /channels/:id/thread-members/:user_id", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/channels/111/thread-members/222", fn conn ->
        json(conn, %{
          "id" => "222",
          "user_id" => "222",
          "join_timestamp" => "2026-01-01T00:00:00Z"
        })
      end)

      assert {:ok, %{"user_id" => "222"}} = Thread.get_member("111", "222")
    end
  end

  # ── list_thread_members ──────────────────────────────────────────────

  describe "list_members/1" do
    test "GET /channels/:id/thread-members", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/channels/111/thread-members", fn conn ->
        json(conn, [
          %{"user_id" => "222", "join_timestamp" => "2026-01-01T00:00:00Z"},
          %{"user_id" => "333", "join_timestamp" => "2026-01-02T00:00:00Z"}
        ])
      end)

      assert {:ok, members} = Thread.list_members("111")
      assert length(members) == 2
    end
  end
end
