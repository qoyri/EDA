defmodule EDA.GuildTest do
  use ExUnit.Case

  alias EDA.Guild

  describe "from_raw/1" do
    test "parses with nested channels, members, roles" do
      raw = %{
        "id" => "g1",
        "name" => "Test Guild",
        "owner_id" => "u1",
        "channels" => [%{"id" => "ch1", "name" => "general", "type" => 0}],
        "members" => [%{"user" => %{"id" => "u1", "username" => "alice"}, "nick" => "ali"}],
        "roles" => [%{"id" => "r1", "name" => "Admin"}],
        "member_count" => 42
      }

      guild = Guild.from_raw(raw)
      assert %Guild{} = guild
      assert guild.id == "g1"
      assert guild.name == "Test Guild"
      assert guild.member_count == 42
      assert [%EDA.Channel{id: "ch1"}] = guild.channels
      assert [%EDA.Member{nick: "ali"}] = guild.members
      assert %EDA.User{id: "u1"} = hd(guild.members).user
      assert [%EDA.Role{id: "r1"}] = guild.roles
    end

    test "handles nil lists" do
      guild = Guild.from_raw(%{"id" => "g1"})
      assert guild.channels == nil
      assert guild.members == nil
      assert guild.roles == nil
    end
  end

  # ── Entity Manager ──

  setup do
    bypass = Bypass.open()
    Application.put_env(:eda, :base_url, "http://localhost:#{bypass.port}")
    Application.put_env(:eda, :token, "test-token")

    on_exit(fn ->
      Application.delete_env(:eda, :base_url)
    end)

    {:ok, bypass: bypass}
  end

  defp json(conn, body) do
    conn
    |> Plug.Conn.put_resp_content_type("application/json")
    |> Plug.Conn.resp(200, Jason.encode!(body))
  end

  describe "fetch/1" do
    test "returns a Guild struct from REST", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/guilds/fetch_test_guild", fn conn ->
        json(conn, %{"id" => "fetch_test_guild", "name" => "Test Guild"})
      end)

      assert {:ok, %Guild{id: "fetch_test_guild", name: "Test Guild"}} =
               Guild.fetch("fetch_test_guild")
    end
  end

  describe "modify/3" do
    test "returns a Guild struct", %{bypass: bypass} do
      Bypass.expect_once(bypass, "PATCH", "/guilds/111", fn conn ->
        json(conn, %{"id" => "111", "name" => "New Name"})
      end)

      assert {:ok, %Guild{name: "New Name"}} = Guild.modify("111", %{name: "New Name"})
    end
  end

  describe "changeset" do
    test "no-op when changeset is empty" do
      guild = Guild.from_raw(%{"id" => "g1", "name" => "Test"})

      cs = Guild.changeset(guild)
      assert {:ok, ^guild} = Guild.apply_changeset(cs)
    end

    test "applies changes via PATCH", %{bypass: bypass} do
      guild = Guild.from_raw(%{"id" => "g1", "name" => "Old"})

      Bypass.expect_once(bypass, "PATCH", "/guilds/g1", fn conn ->
        json(conn, %{"id" => "g1", "name" => "New"})
      end)

      cs =
        guild
        |> Guild.changeset()
        |> Guild.change(:name, "New")

      assert {:ok, %Guild{name: "New"}} = Guild.apply_changeset(cs)
    end
  end

  describe "channels/1" do
    test "returns Channel structs", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/guilds/111/channels", fn conn ->
        json(conn, [%{"id" => "ch1", "name" => "general", "type" => 0}])
      end)

      assert {:ok, [%EDA.Channel{id: "ch1"}]} = Guild.channels("111")
    end
  end

  # ── icon_url ─────────────────────────────────────────────────────────

  describe "icon_url/1" do
    test "returns CDN URL when icon is set" do
      guild = %Guild{id: "123", icon: "abc123"}
      assert Guild.icon_url(guild) == "https://cdn.discordapp.com/icons/123/abc123.png"
    end

    test "returns nil when icon is nil" do
      guild = %Guild{id: "123", icon: nil}
      assert Guild.icon_url(guild) == nil
    end
  end
end
