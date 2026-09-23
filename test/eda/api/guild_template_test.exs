defmodule EDA.API.GuildTemplateTest do
  use ExUnit.Case

  # The API layer returns Discord's maps; these tests go through the entity, which parses them.
  alias EDA.GuildTemplate

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

  defp template_payload(overrides \\ %{}) do
    Map.merge(
      %{
        "code" => "hgM48av5Q69A",
        "name" => "My Template",
        "description" => "A template",
        "usage_count" => 5,
        "creator_id" => "111",
        "creator" => %{"id" => "111", "username" => "creator"},
        "created_at" => "2020-01-01T00:00:00+00:00",
        "updated_at" => "2020-06-01T12:00:00+00:00",
        "source_guild_id" => "222",
        "serialized_source_guild" => %{
          "name" => "Template Guild",
          "roles" => [%{"id" => 0, "name" => "@everyone"}],
          "channels" => [%{"id" => 1, "name" => "general", "type" => 0}]
        },
        "is_dirty" => false
      },
      overrides
    )
  end

  # ── get/1 ────────────────────────────────────────────────────────────

  describe "get/1" do
    test "GET /guilds/templates/:code returns GuildTemplate struct", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/guilds/templates/hgM48av5Q69A", fn conn ->
        json(conn, template_payload())
      end)

      assert {:ok, %EDA.GuildTemplate{code: "hgM48av5Q69A", name: "My Template"}} =
               GuildTemplate.fetch("hgM48av5Q69A")
    end
  end

  # ── list/1 ───────────────────────────────────────────────────────────

  describe "list/1" do
    test "GET /guilds/:id/templates returns list of GuildTemplate structs", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/guilds/222/templates", fn conn ->
        json(conn, [template_payload(), template_payload(%{"code" => "xyz123"})])
      end)

      assert {:ok, templates} = GuildTemplate.list("222")
      assert length(templates) == 2

      assert [%EDA.GuildTemplate{code: "hgM48av5Q69A"}, %EDA.GuildTemplate{code: "xyz123"}] =
               templates
    end
  end

  # ── create/2 ─────────────────────────────────────────────────────────

  describe "create/2" do
    test "POST /guilds/:id/templates sends params and returns GuildTemplate struct", %{
      bypass: bypass
    } do
      Bypass.expect_once(bypass, "POST", "/guilds/222/templates", fn conn ->
        {body, conn} = read_json_body(conn)
        assert body["name"] == "New Template"
        assert body["description"] == "A new template"

        json(
          conn,
          template_payload(%{"name" => "New Template", "description" => "A new template"})
        )
      end)

      assert {:ok, %EDA.GuildTemplate{name: "New Template"}} =
               GuildTemplate.create("222", %{name: "New Template", description: "A new template"})
    end
  end

  # ── modify/3 ─────────────────────────────────────────────────────────

  describe "modify/3" do
    test "PATCH /guilds/:id/templates/:code returns GuildTemplate struct", %{bypass: bypass} do
      Bypass.expect_once(bypass, "PATCH", "/guilds/222/templates/hgM48av5Q69A", fn conn ->
        {body, conn} = read_json_body(conn)
        assert body["name"] == "Updated"
        json(conn, template_payload(%{"name" => "Updated"}))
      end)

      assert {:ok, %EDA.GuildTemplate{name: "Updated"}} =
               GuildTemplate.modify("222", "hgM48av5Q69A", %{name: "Updated"})
    end
  end

  # ── sync/2 ───────────────────────────────────────────────────────────

  describe "sync/2" do
    test "PUT /guilds/:id/templates/:code with empty body returns GuildTemplate struct", %{
      bypass: bypass
    } do
      Bypass.expect_once(bypass, "PUT", "/guilds/222/templates/hgM48av5Q69A", fn conn ->
        {body, conn} = read_json_body(conn)
        assert body == %{}
        json(conn, template_payload())
      end)

      assert {:ok, %EDA.GuildTemplate{code: "hgM48av5Q69A"}} =
               GuildTemplate.sync("222", "hgM48av5Q69A")
    end
  end

  # ── delete/2 ─────────────────────────────────────────────────────────

  describe "delete/2" do
    test "DELETE /guilds/:id/templates/:code returns the deleted GuildTemplate", %{bypass: bypass} do
      Bypass.expect_once(bypass, "DELETE", "/guilds/222/templates/hgM48av5Q69A", fn conn ->
        json(conn, template_payload())
      end)

      assert {:ok, %EDA.GuildTemplate{code: "hgM48av5Q69A"}} =
               GuildTemplate.delete("222", "hgM48av5Q69A")
    end
  end

  # ── create_guild/2 ───────────────────────────────────────────────────

  describe "create_guild/2" do
    test "POST /guilds/templates/:code sends params and returns an EDA.Guild", %{bypass: bypass} do
      guild_data = %{"id" => "999", "name" => "New Guild", "icon" => nil}

      Bypass.expect_once(bypass, "POST", "/guilds/templates/hgM48av5Q69A", fn conn ->
        {body, conn} = read_json_body(conn)
        assert body["name"] == "New Guild"
        json(conn, guild_data)
      end)

      assert {:ok, %EDA.Guild{id: "999", name: "New Guild"}} =
               GuildTemplate.create_guild("hgM48av5Q69A", %{name: "New Guild"})
    end
  end
end
