defmodule EDA.API.RoleTest do
  use ExUnit.Case

  alias EDA.API.Role

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

  # ── get_guild_roles ────────────────────────────────────────────────

  describe "set_colors/4" do
    test "sends only the colors object, never the deprecated color field", %{bypass: bypass} do
      Bypass.expect_once(bypass, "PATCH", "/guilds/111/roles/222", fn conn ->
        {:ok, raw, conn} = Plug.Conn.read_body(conn)
        body = Jason.decode!(raw)

        assert body == %{"colors" => %{"primary_color" => 1, "secondary_color" => 2}}
        refute Map.has_key?(body, "color")

        json(conn, %{"id" => "222", "colors" => body["colors"]})
      end)

      assert {:ok, _} = Role.set_colors("111", "222", EDA.Role.Colors.gradient(1, 2))
    end

    test "holographic sends the three enforced values", %{bypass: bypass} do
      Bypass.expect_once(bypass, "PATCH", "/guilds/111/roles/333", fn conn ->
        {:ok, raw, conn} = Plug.Conn.read_body(conn)

        assert Jason.decode!(raw)["colors"] == %{
                 "primary_color" => 11_127_295,
                 "secondary_color" => 16_759_788,
                 "tertiary_color" => 16_761_760
               }

        json(conn, %{"id" => "333"})
      end)

      assert {:ok, _} = Role.set_colors("111", "333", EDA.Role.Colors.holographic())
    end

    test "a solid colour omits the other keys", %{bypass: bypass} do
      Bypass.expect_once(bypass, "PATCH", "/guilds/111/roles/444", fn conn ->
        {:ok, raw, conn} = Plug.Conn.read_body(conn)

        assert Jason.decode!(raw)["colors"] == %{"primary_color" => 255}

        json(conn, %{"id" => "444"})
      end)

      assert {:ok, _} = Role.set_colors("111", "444", EDA.Role.Colors.solid(255))
    end

    test "accepts a plain map too", %{bypass: bypass} do
      Bypass.expect_once(bypass, "PATCH", "/guilds/111/roles/555", fn conn ->
        {:ok, raw, conn} = Plug.Conn.read_body(conn)

        assert Jason.decode!(raw)["colors"] == %{"primary_color" => 7}

        json(conn, %{"id" => "555"})
      end)

      assert {:ok, _} = Role.set_colors("111", "555", %{primary_color: 7})
    end

    test "forwards :reason as an audit log header", %{bypass: bypass} do
      Bypass.expect_once(bypass, "PATCH", "/guilds/111/roles/666", fn conn ->
        assert Plug.Conn.get_req_header(conn, "x-audit-log-reason") == ["event%20colours"]
        json(conn, %{"id" => "666"})
      end)

      assert {:ok, _} =
               Role.set_colors("111", "666", EDA.Role.Colors.solid(1), reason: "event colours")
    end
  end

  describe "member_counts/1" do
    test "GET /guilds/:id/roles/member-counts", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/guilds/111/roles/member-counts", fn conn ->
        # Shape taken from a live guild: role_id => integer, @everyone absent.
        json(conn, %{
          "938496731396599808" => 179,
          "964090281647542342" => 272,
          "1174605032830812240" => 1
        })
      end)

      assert {:ok, counts} = Role.member_counts("111")
      assert counts["938496731396599808"] == 179
      assert counts["1174605032830812240"] == 1
      assert map_size(counts) == 3
    end

    test "accepts an integer guild id", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/guilds/222/roles/member-counts", fn conn ->
        json(conn, %{})
      end)

      assert {:ok, %{}} = Role.member_counts(222)
    end

    test "propagates errors", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/guilds/333/roles/member-counts", fn conn ->
        json(conn, %{"message" => "Missing Access", "code" => 50_001}, 403)
      end)

      assert {:error, _} = Role.member_counts("333")
    end
  end

  describe "list/1" do
    test "GET /guilds/:id/roles", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/guilds/111/roles", fn conn ->
        json(conn, [%{"id" => "333", "name" => "Admin"}])
      end)

      assert {:ok, [%{"name" => "Admin"}]} = Role.list("111")
    end
  end

  # ── create_guild_role ──────────────────────────────────────────────

  describe "create/2" do
    test "POST /guilds/:id/roles with keyword opts", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/guilds/111/roles", fn conn ->
        {body, conn} = read_json_body(conn)
        assert body["name"] == "Mods"
        assert body["color"] == 0xFF0000
        json(conn, %{"id" => "333", "name" => "Mods"})
      end)

      assert {:ok, %{"name" => "Mods"}} =
               Role.create("111", name: "Mods", color: 0xFF0000)
    end

    test "POST /guilds/:id/roles without opts", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/guilds/111/roles", fn conn ->
        json(conn, %{"id" => "333", "name" => "new role"})
      end)

      assert {:ok, _} = Role.create("111")
    end
  end

  # ── modify_guild_role ──────────────────────────────────────────────

  describe "modify/3" do
    test "PATCH /guilds/:id/roles/:id", %{bypass: bypass} do
      Bypass.expect_once(bypass, "PATCH", "/guilds/111/roles/333", fn conn ->
        {body, conn} = read_json_body(conn)
        assert body["name"] == "Super Mods"
        json(conn, %{"id" => "333", "name" => "Super Mods"})
      end)

      assert {:ok, %{"name" => "Super Mods"}} =
               Role.modify("111", "333", %{name: "Super Mods"})
    end
  end

  # ── delete_guild_role ──────────────────────────────────────────────

  describe "delete/2" do
    test "DELETE /guilds/:id/roles/:id", %{bypass: bypass} do
      Bypass.expect_once(bypass, "DELETE", "/guilds/111/roles/333", fn conn ->
        Plug.Conn.resp(conn, 204, "")
      end)

      assert :ok = Role.delete("111", "333")
    end
  end

  # ── modify_guild_role_positions ────────────────────────────────────

  describe "modify_positions/2" do
    test "PATCH /guilds/:id/roles", %{bypass: bypass} do
      Bypass.expect_once(bypass, "PATCH", "/guilds/111/roles", fn conn ->
        {body, conn} = read_json_body(conn)
        assert length(body) == 2
        json(conn, body)
      end)

      positions = [%{id: "333", position: 1}, %{id: "444", position: 2}]
      assert {:ok, _} = Role.modify_positions("111", positions)
    end
  end
end
