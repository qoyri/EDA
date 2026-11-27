defmodule EDA.API.ComputedPermissionsTest do
  @moduledoc """
  The endpoints that return a member's or a role's permissions as Discord computes them, and
  the audit log reason of a reorder.
  """
  use ExUnit.Case

  alias EDA.Permission

  setup do
    bypass = Bypass.open()
    Application.put_env(:eda, :base_url, "http://localhost:#{bypass.port}")
    Application.put_env(:eda, :token, "test-token")
    on_exit(fn -> Application.delete_env(:eda, :base_url) end)
    {:ok, bypass: bypass}
  end

  defp json(conn, body, status \\ 200) do
    conn
    |> Plug.Conn.put_resp_content_type("application/json")
    |> Plug.Conn.resp(status, Jason.encode!(body))
  end

  describe "in a guild" do
    test "a member's permissions", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/guilds/111/permissions/member/222", fn conn ->
        json(conn, %{"permissions" => "2052"})
      end)

      assert {:ok, %{"permissions" => "2052"}} = EDA.API.Member.permissions("111", "222")
    end

    test "fetch_in_guild/2 returns the bitset", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/guilds/111/permissions/member/222", fn conn ->
        json(conn, %{"permissions" => "2052"})
      end)

      assert {:ok, 2052} = Permission.fetch_in_guild("111", 222)
      assert Permission.to_list(2052) == [:ban_members, :send_messages]
    end

    test "a role's permissions, with @everyone", %{bypass: bypass} do
      Bypass.expect(bypass, "GET", "/guilds/111/permissions/role/333", fn conn ->
        json(conn, %{"permissions" => "1024"})
      end)

      assert {:ok, %{"permissions" => "1024"}} = EDA.API.Role.permissions("111", "333")
      assert {:ok, 1024} = Permission.fetch_for_role("111", "333")
    end

    test "a permission bitfield beyond 53 bits is not rounded", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/guilds/111/permissions/member/222", fn conn ->
        json(conn, %{"permissions" => "2251799813685247"})
      end)

      assert {:ok, 2_251_799_813_685_247} = Permission.fetch_in_guild("111", "222")
    end

    test "an error comes back as it is", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/guilds/111/permissions/member/222", fn conn ->
        json(conn, %{"code" => 10_007, "message" => "Unknown Member"}, 404)
      end)

      assert {:error, _} = Permission.fetch_in_guild("111", "222")
    end
  end

  describe "in a channel" do
    test "a member's permissions, masked by default", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/channels/444/permissions/member/222", fn conn ->
        assert conn.query_string == ""
        json(conn, %{"permissions" => "0"})
      end)

      assert {:ok, 0} = Permission.fetch_in_channel("444", "222")
    end

    test "implicit: false asks for the permissions before masking", %{bypass: bypass} do
      Bypass.expect(bypass, "GET", "/channels/444/permissions/member/222", fn conn ->
        assert conn.query_string == "implicit=false"
        json(conn, %{"permissions" => "2048"})
      end)

      assert {:ok, %{"permissions" => "2048"}} =
               EDA.API.Channel.member_permissions("444", "222", implicit: false)

      assert {:ok, 2048} = Permission.fetch_in_channel("444", "222", implicit: false)
    end

    test "a role's permissions", %{bypass: bypass} do
      Bypass.expect(bypass, "GET", "/channels/444/permissions/role/333", fn conn ->
        json(conn, %{"permissions" => "1024"})
      end)

      assert {:ok, %{"permissions" => "1024"}} = EDA.API.Channel.role_permissions("444", "333")
      assert {:ok, 1024} = Permission.fetch_for_role_in_channel("444", "333")
    end

    test "an option Discord does not define is refused before the request" do
      assert_raise ArgumentError, ~r/unknown option/, fn ->
        EDA.API.Channel.member_permissions("444", "222", implict: false)
      end
    end
  end

  describe "a reorder's audit log reason" do
    test "channel positions", %{bypass: bypass} do
      Bypass.expect_once(bypass, "PATCH", "/guilds/111/channels", fn conn ->
        assert Plug.Conn.get_req_header(conn, "x-audit-log-reason") == ["spring%20cleaning"]
        Plug.Conn.resp(conn, 204, "")
      end)

      assert :ok =
               EDA.API.Channel.modify_positions("111", [%{id: "2", position: 0}],
                 reason: "spring cleaning"
               )
    end

    test "role positions, through the typed call", %{bypass: bypass} do
      Bypass.expect_once(bypass, "PATCH", "/guilds/111/roles", fn conn ->
        assert Plug.Conn.get_req_header(conn, "x-audit-log-reason") == ["tidy"]
        json(conn, [%{"id" => "2", "name" => "mods", "position" => 1}])
      end)

      assert {:ok, [%EDA.Role{id: "2", guild_id: "111", position: 1}]} =
               EDA.Role.modify_positions("111", [%{id: "2", position: 1}], reason: "tidy")
    end
  end
end
