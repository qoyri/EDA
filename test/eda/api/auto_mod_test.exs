defmodule EDA.API.AutoModTest do
  use ExUnit.Case

  # The API layer returns Discord's maps; these tests go through the entity, which parses them.
  alias EDA.AutoMod

  setup do
    bypass = Bypass.open()
    Application.put_env(:eda, :base_url, "http://localhost:#{bypass.port}")
    Application.put_env(:eda, :token, "test-token")

    on_exit(fn ->
      Application.delete_env(:eda, :base_url)
    end)

    {:ok, bypass: bypass}
  end

  defp json(conn, body, status \\ 200) do
    conn
    |> Plug.Conn.put_resp_content_type("application/json")
    |> Plug.Conn.resp(status, Jason.encode!(body))
  end

  defp read_json_body(conn) do
    {:ok, raw, conn} = Plug.Conn.read_body(conn)
    {Jason.decode!(raw), conn}
  end

  @rule_json %{
    "id" => "r1",
    "guild_id" => "g1",
    "name" => "Block spam",
    "creator_id" => "u1",
    "event_type" => 1,
    "trigger_type" => 1,
    "trigger_metadata" => %{"keyword_filter" => ["spam"]},
    "actions" => [%{"type" => 1}],
    "enabled" => true,
    "exempt_roles" => [],
    "exempt_channels" => []
  }

  # ── list/1 ─────────────────────────────────────────────────────────

  describe "list/1" do
    test "GET /guilds/:id/auto-moderation/rules returns AutoMod structs", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/guilds/g1/auto-moderation/rules", fn conn ->
        json(conn, [@rule_json])
      end)

      assert {:ok, [%EDA.AutoMod{id: "r1", name: "Block spam"}]} = AutoMod.list("g1")
    end
  end

  # ── get_rule/2 ─────────────────────────────────────────────────────

  describe "get_rule/2" do
    test "GET /guilds/:id/auto-moderation/rules/:rid returns AutoMod struct", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/guilds/g1/auto-moderation/rules/r1", fn conn ->
        json(conn, @rule_json)
      end)

      assert {:ok, %EDA.AutoMod{id: "r1", trigger_type: :keyword}} =
               AutoMod.fetch_rule("g1", "r1")
    end
  end

  # ── create/2 ───────────────────────────────────────────────────────

  describe "create/2" do
    test "POST /guilds/:id/auto-moderation/rules returns AutoMod struct", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/guilds/g1/auto-moderation/rules", fn conn ->
        {body, conn} = read_json_body(conn)
        assert body["name"] == "Block spam"
        assert body["trigger_type"] == 1
        json(conn, @rule_json)
      end)

      params = %{
        name: "Block spam",
        event_type: 1,
        trigger_type: 1,
        actions: [%{type: 1}]
      }

      assert {:ok, %EDA.AutoMod{id: "r1"}} = AutoMod.create("g1", params)
    end
  end

  # ── modify/3 ───────────────────────────────────────────────────────

  describe "modify/3" do
    test "PATCH /guilds/:id/auto-moderation/rules/:rid returns AutoMod struct", %{bypass: bypass} do
      Bypass.expect_once(bypass, "PATCH", "/guilds/g1/auto-moderation/rules/r1", fn conn ->
        {body, conn} = read_json_body(conn)
        assert body["name"] == "Updated"
        json(conn, Map.put(@rule_json, "name", "Updated"))
      end)

      assert {:ok, %EDA.AutoMod{name: "Updated"}} =
               AutoMod.modify("g1", "r1", %{name: "Updated"})
    end
  end

  # ── delete_rule/2 ──────────────────────────────────────────────────

  describe "delete_rule/2" do
    test "DELETE /guilds/:id/auto-moderation/rules/:rid returns :ok", %{bypass: bypass} do
      Bypass.expect_once(bypass, "DELETE", "/guilds/g1/auto-moderation/rules/r1", fn conn ->
        Plug.Conn.resp(conn, 204, "")
      end)

      assert :ok = AutoMod.delete("g1", "r1")
    end
  end
end
