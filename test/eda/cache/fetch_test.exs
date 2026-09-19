defmodule EDA.Cache.FetchTest do
  use ExUnit.Case

  # Not async — shares Application env and ETS tables.

  setup do
    bypass = Bypass.open()
    Application.put_env(:eda, :base_url, "http://localhost:#{bypass.port}")
    Application.put_env(:eda, :token, "test-token")

    on_exit(fn ->
      Application.delete_env(:eda, :base_url)
      Application.delete_env(:eda, :cache)
      EDA.Cache.Config.setup()
    end)

    {:ok, bypass: bypass}
  end

  defp json(conn, body, status \\ 200) do
    conn
    |> Plug.Conn.put_resp_content_type("application/json")
    |> Plug.Conn.resp(status, Jason.encode!(body))
  end

  describe "fetch_role/2 cache policy" do
    test "consults the policy with the real role, never nil", %{bypass: bypass} do
      test_pid = self()

      Application.put_env(:eda, :cache,
        roles: [
          policy: fn entity, key, value ->
            send(test_pid, {:policy, entity, key, value})
            :cache
          end
        ]
      )

      EDA.Cache.Config.setup()

      Bypass.expect_once(bypass, "GET", "/guilds/frp1/roles", fn conn ->
        json(conn, [%{"id" => "frp1role", "name" => "Admin"}])
      end)

      assert {:ok, role} = EDA.Cache.fetch_role("frp1", "frp1role")
      assert role["name"] == "Admin"

      # The policy must be asked about an actual role. Passing nil key/value
      # breaks EDA.Cache.Policy.check/4's contract and makes per-role policies
      # impossible to write.
      assert_received {:policy, :role, key, value}
      assert key == {"frp1", "frp1role"}
      assert value["name"] == "Admin"

      # ...and it must be asked exactly once per role, not once for the list
      # and then again inside EDA.Cache.Role.create/2.
      refute_received {:policy, _, _, _}
    end
  end

  describe "fetch_guild/1" do
    test "returns cached data without REST call" do
      guild = %{"id" => "fg1", "name" => "Cached Guild"}
      EDA.Cache.Guild.create(guild)

      assert {:ok, cached} = EDA.Cache.fetch_guild("fg1")
      assert cached["name"] == "Cached Guild"
    end

    test "calls REST on cache miss", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/guilds/fg2", fn conn ->
        json(conn, %{"id" => "fg2", "name" => "REST Guild"})
      end)

      assert {:ok, guild} = EDA.Cache.fetch_guild("fg2")
      assert guild["name"] == "REST Guild"
    end

    test "propagates REST errors", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/guilds/fg3", fn conn ->
        json(conn, %{"message" => "Unknown Guild"}, 404)
      end)

      assert {:error, _} = EDA.Cache.fetch_guild("fg3")
    end
  end

  describe "fetch_member/2" do
    test "returns cached member without REST call" do
      member = %{"user" => %{"id" => "u1"}, "nick" => "cached"}
      EDA.Cache.Member.create("gm1", member)

      assert {:ok, cached} = EDA.Cache.fetch_member("gm1", "u1")
      assert cached["nick"] == "cached"
    end

    test "calls REST on cache miss", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/guilds/gm2/members/u2", fn conn ->
        json(conn, %{
          "user" => %{"id" => "u2"},
          "nick" => "from_rest",
          "guild_id" => "gm2"
        })
      end)

      assert {:ok, member} = EDA.Cache.fetch_member("gm2", "u2")
      assert member["nick"] == "from_rest"
    end

    test "REST result not cached when policy is :none", %{bypass: bypass} do
      Application.put_env(:eda, :cache, members: [policy: :none])
      EDA.Cache.Config.setup()

      Bypass.expect_once(bypass, "GET", "/guilds/gm3/members/u3", fn conn ->
        json(conn, %{
          "user" => %{"id" => "u3"},
          "nick" => "rest_only",
          "guild_id" => "gm3"
        })
      end)

      assert {:ok, member} = EDA.Cache.fetch_member("gm3", "u3")
      assert member["nick"] == "rest_only"

      # Should not be in cache
      assert EDA.Cache.get_member("gm3", "u3") == nil
    end
  end

  describe "fetch_user/1" do
    test "calls REST on miss", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/users/fu1", fn conn ->
        json(conn, %{"id" => "fu1", "username" => "testuser"})
      end)

      assert {:ok, user} = EDA.Cache.fetch_user("fu1")
      assert user["username"] == "testuser"
    end
  end

  describe "telemetry" do
    test "[:eda, :cache, :fallback] is emitted on REST call", %{bypass: bypass} do
      :telemetry.attach(
        "fallback-test",
        [:eda, :cache, :fallback],
        fn event, measurements, metadata, _ ->
          send(self(), {:telemetry, event, measurements, metadata})
        end,
        nil
      )

      Bypass.expect_once(bypass, "GET", "/guilds/ft1", fn conn ->
        json(conn, %{"id" => "ft1", "name" => "Telemetry Guild"})
      end)

      EDA.Cache.fetch_guild("ft1")

      assert_received {:telemetry, [:eda, :cache, :fallback], %{count: 1}, %{cache: :guilds}}

      :telemetry.detach("fallback-test")
    end
  end
end
