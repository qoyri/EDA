defmodule EDA.RoleTest do
  use ExUnit.Case

  alias EDA.Role

  doctest EDA.Role.Tags

  describe "from_raw/1" do
    test "a managed role's tags, the keys Discord sends as null read as true" do
      role =
        Role.from_raw(%{
          "id" => "r9",
          "tags" => %{
            "integration_id" => "5",
            "subscription_listing_id" => "6",
            "available_for_purchase" => nil
          }
        })

      assert role.tags == %Role.Tags{
               integration_id: "5",
               subscription_listing_id: "6",
               available_for_purchase: true
             }

      assert Role.from_raw(%{"id" => "r10"}).tags == nil
    end

    test "parses all fields" do
      raw = %{
        "id" => "r1",
        "name" => "Admin",
        "color" => 16_711_680,
        "hoist" => true,
        "position" => 5,
        "permissions" => "8",
        "managed" => false,
        "mentionable" => true
      }

      role = Role.from_raw(raw)
      assert %Role{} = role
      assert role.id == "r1"
      assert role.name == "Admin"
      assert role.color == 16_711_680
      assert role.hoist == true
      assert role.permissions == "8"
    end
  end

  describe "mention/1" do
    test "returns role mention" do
      role = Role.from_raw(%{"id" => "r1", "name" => "Admin"})
      assert Role.mention(role) == "<@&r1>"
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

  describe "fetch_role/2" do
    test "returns a Role struct from REST", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/guilds/fetch_g/roles", fn conn ->
        json(conn, [
          %{"id" => "fetch_r1", "name" => "Admin"},
          %{"id" => "fetch_r2", "name" => "Mod"}
        ])
      end)

      assert {:ok, %Role{id: "fetch_r1", name: "Admin"}} =
               Role.fetch_role("fetch_g", "fetch_r1")
    end

    test "returns error when role not found", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/guilds/fetch_g/roles", fn conn ->
        json(conn, [%{"id" => "fetch_r2", "name" => "Mod"}])
      end)

      assert {:error, :not_found} = Role.fetch_role("fetch_g", "fetch_r999")
    end
  end

  describe "create/3" do
    test "returns a Role struct", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/guilds/g1/roles", fn conn ->
        json(conn, %{"id" => "r3", "name" => "New Role"})
      end)

      assert {:ok, %Role{id: "r3", name: "New Role"}} = Role.create("g1", %{name: "New Role"})
    end
  end

  describe "modify/4" do
    test "returns a Role struct", %{bypass: bypass} do
      Bypass.expect_once(bypass, "PATCH", "/guilds/g1/roles/r1", fn conn ->
        json(conn, %{"id" => "r1", "name" => "Renamed"})
      end)

      assert {:ok, %Role{name: "Renamed"}} = Role.modify("g1", "r1", %{name: "Renamed"})
    end
  end

  describe "changeset" do
    test "no-op when changeset is empty" do
      role = Role.from_raw(%{"id" => "r1", "name" => "Admin"})
      cs = Role.changeset(role)
      assert {:ok, ^role} = Role.apply_changeset("g1", cs)
    end

    test "applies changes via PATCH", %{bypass: bypass} do
      role = Role.from_raw(%{"id" => "r1", "name" => "Old"})

      Bypass.expect_once(bypass, "PATCH", "/guilds/g1/roles/r1", fn conn ->
        json(conn, %{"id" => "r1", "name" => "New", "color" => 255})
      end)

      cs =
        role
        |> Role.changeset()
        |> Role.change(:name, "New")
        |> Role.change(:color, 255)

      assert {:ok, %Role{name: "New", color: 255}} = Role.apply_changeset("g1", cs)
    end
  end
end
