defmodule EDA.API.GuildTest do
  use ExUnit.Case

  alias EDA.API.Guild

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

  # ── get_guild ──────────────────────────────────────────────────────

  describe "get/1" do
    test "GET /guilds/:id", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/guilds/111", fn conn ->
        json(conn, %{"id" => "111", "name" => "Test"})
      end)

      assert {:ok, %{"name" => "Test"}} = Guild.get("111")
    end
  end

  # ── modify_guild ───────────────────────────────────────────────────

  describe "modify/2" do
    test "PATCH /guilds/:id", %{bypass: bypass} do
      Bypass.expect_once(bypass, "PATCH", "/guilds/111", fn conn ->
        {body, conn} = read_json_body(conn)
        assert body["name"] == "New Name"
        json(conn, %{"id" => "111", "name" => "New Name"})
      end)

      assert {:ok, %{"name" => "New Name"}} = Guild.modify("111", %{name: "New Name"})
    end
  end

  # ── get_guild_channels ─────────────────────────────────────────────

  describe "channels/1" do
    test "GET /guilds/:id/channels", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/guilds/111/channels", fn conn ->
        json(conn, [%{"id" => "222"}])
      end)

      assert {:ok, [%{"id" => "222"}]} = Guild.channels("111")
    end
  end

  # ── get_guild_prune_count ──────────────────────────────────────────

  describe "prune_count/2" do
    test "GET /guilds/:id/prune", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/guilds/111/prune", fn conn ->
        conn = Plug.Conn.fetch_query_params(conn)
        assert conn.query_params["days"] == "7"
        json(conn, %{"pruned" => 42})
      end)

      assert {:ok, %{"pruned" => 42}} = Guild.prune_count("111", days: 7)
    end
  end

  # ── begin_guild_prune ──────────────────────────────────────────────

  describe "prune/2" do
    test "POST /guilds/:id/prune", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/guilds/111/prune", fn conn ->
        {body, conn} = read_json_body(conn)
        assert body["days"] == 7
        json(conn, %{"pruned" => 42})
      end)

      assert {:ok, %{"pruned" => 42}} = Guild.prune("111", %{days: 7})
    end
  end

  # ── get_guild_invites ──────────────────────────────────────────────

  describe "invites/1" do
    test "GET /guilds/:id/invites", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/guilds/111/invites", fn conn ->
        json(conn, [%{"code" => "abc123"}])
      end)

      assert {:ok, [%{"code" => "abc123"}]} = Guild.invites("111")
    end
  end

  # ── get_guild_audit_log ────────────────────────────────────────────

  describe "audit_log/2" do
    test "GET /guilds/:id/audit-logs returns parsed entries", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/guilds/111/audit-logs", fn conn ->
        conn = Plug.Conn.fetch_query_params(conn)
        assert conn.query_params["limit"] == "10"

        json(conn, %{
          "audit_log_entries" => [
            %{
              "id" => "entry1",
              "action_type" => 22,
              "user_id" => "mod1",
              "target_id" => "user1",
              "changes" => [%{"key" => "name", "old_value" => "a", "new_value" => "b"}]
            }
          ],
          "users" => [%{"id" => "mod1"}],
          "webhooks" => []
        })
      end)

      assert {:ok, %{"audit_log_entries" => [_]}} = Guild.audit_log("111", limit: 10)
    end

    test "EDA.AuditLog.fetch_log/2 parses the entries", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/guilds/111/audit-logs", fn conn ->
        json(conn, %{
          "audit_log_entries" => [
            %{
              "id" => "entry1",
              "action_type" => 22,
              "user_id" => "mod1",
              "target_id" => "user1",
              "changes" => [%{"key" => "name", "old_value" => "a", "new_value" => "b"}]
            }
          ],
          "users" => [%{"id" => "mod1"}],
          "webhooks" => []
        })
      end)

      assert {:ok, %EDA.AuditLog{entries: [entry], users: [%EDA.User{}], webhooks: []}} =
               EDA.AuditLog.fetch_log("111", limit: 10)

      assert %EDA.AuditLog.Entry{} = entry
      assert entry.id == "entry1"
      assert entry.action_type == :member_ban_add
      assert [%EDA.AuditLog.Change{key: "name"}] = entry.changes
    end

    test "resolves atom action_type to integer", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/guilds/111/audit-logs", fn conn ->
        conn = Plug.Conn.fetch_query_params(conn)
        assert conn.query_params["action_type"] == "22"
        json(conn, %{"audit_log_entries" => [], "users" => [], "webhooks" => []})
      end)

      assert {:ok, %{"audit_log_entries" => []}} =
               Guild.audit_log("111", action_type: :member_ban_add)
    end

    test "fetch_log/2 parses what the entries point at", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/guilds/111/audit-logs", fn conn ->
        json(conn, %{
          "audit_log_entries" => [],
          "users" => [],
          "webhooks" => [],
          "application_commands" => [%{"id" => "c1", "name" => "ban"}],
          "auto_moderation_rules" => [%{"id" => "r1", "name" => "no links"}],
          "guild_scheduled_events" => [%{"id" => "e1", "name" => "raid"}],
          "integrations" => [%{"id" => "i1", "name" => "bot"}],
          "threads" => [%{"id" => "t1", "name" => "appeal"}]
        })
      end)

      assert {:ok, log} = EDA.AuditLog.fetch_log("111")
      assert [%EDA.Command{name: "ban"}] = log.application_commands
      assert [%EDA.AutoMod{name: "no links"}] = log.auto_moderation_rules
      assert [%EDA.ScheduledEvent{name: "raid"}] = log.guild_scheduled_events
      assert [%EDA.Integration{name: "bot"}] = log.integrations
      assert [%EDA.Channel{name: "appeal"}] = log.threads
    end
  end
end
