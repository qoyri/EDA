defmodule EDA.API.MemberTest do
  use ExUnit.Case

  alias EDA.API.Member

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

  # ── get_guild_member ───────────────────────────────────────────────

  describe "get/2" do
    test "GET /guilds/:id/members/:id", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/guilds/111/members/222", fn conn ->
        json(conn, %{"user" => %{"id" => "222"}})
      end)

      assert {:ok, %{"user" => %{"id" => "222"}}} = Member.get("111", "222")
    end
  end

  # ── list_guild_members ─────────────────────────────────────────────

  describe "list/2" do
    test "GET /guilds/:id/members with opts", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/guilds/111/members", fn conn ->
        conn = Plug.Conn.fetch_query_params(conn)
        assert conn.query_params["limit"] == "100"
        json(conn, [%{"user" => %{"id" => "1"}}])
      end)

      assert {:ok, [_]} = Member.list("111", limit: 100)
    end
  end

  # ── search_guild_members ───────────────────────────────────────────

  describe "search/3" do
    test "GET /guilds/:id/members/search", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/guilds/111/members/search", fn conn ->
        conn = Plug.Conn.fetch_query_params(conn)
        assert conn.query_params["query"] == "bob"
        assert conn.query_params["limit"] == "5"
        json(conn, [%{"user" => %{"username" => "bob"}}])
      end)

      assert {:ok, [_]} = Member.search("111", "bob", limit: 5)
    end
  end

  # ── modify_guild_member ────────────────────────────────────────────

  describe "modify/3" do
    test "PATCH /guilds/:id/members/:id", %{bypass: bypass} do
      Bypass.expect_once(bypass, "PATCH", "/guilds/111/members/222", fn conn ->
        {body, conn} = read_json_body(conn)
        assert body["nick"] == "new-nick"
        json(conn, %{"nick" => "new-nick"})
      end)

      assert {:ok, _} = Member.modify("111", "222", %{nick: "new-nick"})
    end
  end

  # ── remove_guild_member ────────────────────────────────────────────

  describe "remove/2" do
    test "DELETE /guilds/:id/members/:id (kick)", %{bypass: bypass} do
      Bypass.expect_once(bypass, "DELETE", "/guilds/111/members/222", fn conn ->
        Plug.Conn.resp(conn, 204, "")
      end)

      assert :ok = Member.remove("111", "222")
    end
  end

  # ── add_guild_member_role ──────────────────────────────────────────

  describe "add_role/3" do
    test "PUT /guilds/:id/members/:id/roles/:id", %{bypass: bypass} do
      Bypass.expect_once(bypass, "PUT", "/guilds/111/members/222/roles/333", fn conn ->
        Plug.Conn.resp(conn, 204, "")
      end)

      assert :ok = Member.add_role("111", "222", "333")
    end
  end

  # ── remove_guild_member_role ───────────────────────────────────────

  describe "remove_role/3" do
    test "DELETE /guilds/:id/members/:id/roles/:id", %{bypass: bypass} do
      Bypass.expect_once(bypass, "DELETE", "/guilds/111/members/222/roles/333", fn conn ->
        Plug.Conn.resp(conn, 204, "")
      end)

      assert :ok = Member.remove_role("111", "222", "333")
    end
  end

  # ── stream ───────────────────────────────────────────────────────────

  describe "stream/2" do
    test "paginates after-only with correct cursor", %{bypass: bypass} do
      call_count = :counters.new(1, [])

      Bypass.expect(bypass, "GET", "/guilds/111/members", fn conn ->
        :counters.add(call_count, 1, 1)
        conn = Plug.Conn.fetch_query_params(conn)

        case :counters.get(call_count, 1) do
          1 ->
            assert conn.query_params["limit"] == "2"
            refute conn.query_params["after"]

            json(conn, [
              %{"user" => %{"id" => "1"}},
              %{"user" => %{"id" => "2"}}
            ])

          2 ->
            assert conn.query_params["after"] == "2"
            json(conn, [%{"user" => %{"id" => "3"}}])
        end
      end)

      members = Member.stream("111", per_page: 2) |> Enum.to_list()
      assert length(members) == 3
    end

    test "empty guild returns empty stream", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/guilds/111/members", fn conn ->
        json(conn, [])
      end)

      assert Member.stream("111") |> Enum.to_list() == []
    end
  end

  # ── move_voice ───────────────────────────────────────────────────────

  describe "move_voice/3" do
    test "PATCH /guilds/:id/members/:id with channel_id", %{bypass: bypass} do
      Bypass.expect_once(bypass, "PATCH", "/guilds/111/members/222", fn conn ->
        {body, conn} = read_json_body(conn)
        assert body["channel_id"] == "333"
        json(conn, %{"user" => %{"id" => "222"}})
      end)

      assert {:ok, _} = Member.move_voice("111", "222", "333")
    end

    test "PATCH with nil disconnects from voice", %{bypass: bypass} do
      Bypass.expect_once(bypass, "PATCH", "/guilds/111/members/222", fn conn ->
        {body, conn} = read_json_body(conn)
        assert body["channel_id"] == nil
        json(conn, %{"user" => %{"id" => "222"}})
      end)

      assert {:ok, _} = Member.move_voice("111", "222", nil)
    end
  end
end
