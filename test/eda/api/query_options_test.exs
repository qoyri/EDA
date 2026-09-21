defmodule EDA.API.QueryOptionsTest do
  @moduledoc """
  Every endpoint that builds a query string declares the parameters Discord defines.

  Discord ignores a query parameter it does not recognise, so a misspelt filter does not
  fail — it silently changes the result. In 0.4.x an unknown key is reported with a warning
  and the request is sent unchanged; 0.5 will refuse it. `limit` mistyped on a member listing returns the
  default of **one** member instead of a thousand, and `user_id` mistyped on an entitlement
  listing returns everybody's entitlements rather than one person's.

  The accepted sets below were taken from Discord's own published request types, not from
  memory, and each one is exercised in full so that a set which is too *narrow* fails here
  rather than in a user's code.
  """

  # NOT async — Bypass and the Application env are global.
  use ExUnit.Case

  import ExUnit.CaptureLog

  setup do
    bypass = Bypass.open()
    Application.put_env(:eda, :base_url, "http://localhost:#{bypass.port}")
    Application.put_env(:eda, :token, "test-token")

    on_exit(fn -> Application.delete_env(:eda, :base_url) end)

    {:ok, bypass: bypass}
  end

  # {label, fun/1 taking opts, accepted options}
  defp endpoints do
    [
      {"Member.list/2", &EDA.API.Member.list("111", &1), [limit: 100, after: "1"]},
      {"Ban.list/2", &EDA.API.Ban.list("111", &1), [before: "1", after: "2", limit: 50]},
      {"Message.list/2", &EDA.API.Message.list("111", &1),
       [around: "1", before: "2", after: "3", limit: 50]},
      {"Message.pins/2", &EDA.API.Message.pins("111", &1), [before: "1", limit: 10]},
      {"Guild.prune_count/2", &EDA.API.Guild.prune_count("111", &1),
       [days: 7, include_roles: "1"]},
      {"Guild.audit_log/2", &EDA.API.Guild.audit_log("111", &1),
       [user_id: "1", before: "2", after: "3", limit: 10]},
      {"Reaction.list/4", &EDA.API.Reaction.list("111", "222", "👍", &1),
       [type: 0, after: "1", limit: 25]},
      {"ScheduledEvent.list/2", &EDA.API.ScheduledEvent.list("111", &1), [with_user_count: true]},
      {"ScheduledEvent.get/3", &EDA.API.ScheduledEvent.get("111", "222", &1),
       [with_user_count: true]},
      {"ScheduledEvent.users/3", &EDA.API.ScheduledEvent.users("111", "222", &1),
       [limit: 10, with_member: true, before: "1", after: "2"]},
      {"Subscription.list/2", &EDA.API.Subscription.list("sku1", &1),
       [user_id: "1", before: "2", after: "3", limit: 10]}
    ]
  end

  describe "an unknown option is reported" do
    test "at every query endpoint, naming the path", %{bypass: bypass} do
      # Bypass is down: the call fails at the transport, which is after the check ran.
      Bypass.down(bypass)

      Enum.each(endpoints(), fn {label, call, _accepted} ->
        log = capture_log(fn -> call.(nope: 1) end)

        assert log =~ "unknown option [:nope]", "#{label} did not warn: #{inspect(log)}"
        assert log =~ "EDA 0.5 will raise", "#{label} should announce the 0.5 behaviour"
      end)
    end

    test "the warning lists what is accepted", %{bypass: bypass} do
      Bypass.down(bypass)

      log = capture_log(fn -> EDA.API.Member.list("111", limits: 10) end)

      assert log =~ "[:limits]"
      assert log =~ ":limit"
      assert log =~ ":after"
      assert log =~ "/guilds/111/members"
    end

    test "several are reported together", %{bypass: bypass} do
      Bypass.down(bypass)

      log = capture_log(fn -> EDA.API.Message.list("111", a: 1, b: 2) end)

      assert log =~ "unknown options [:a, :b]"
    end

    test "the request still goes out unchanged, unknown key included", %{bypass: bypass} do
      # A patch release must not stop a working call. If EDA's list lagged behind Discord,
      # a genuinely new parameter still reaches it.
      Bypass.expect_once(bypass, "GET", "/guilds/111/members", fn conn ->
        assert URI.decode_query(conn.query_string) == %{"limit" => "5", "brand_new" => "x"}

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!([]))
      end)

      capture_log(fn ->
        assert {:ok, []} = EDA.API.Member.list("111", limit: 5, brand_new: "x")
      end)
    end
  end

  describe "every documented option is accepted" do
    test "no endpoint's set is too narrow — its own options raise no warning",
         %{bypass: bypass} do
      Bypass.down(bypass)

      Enum.each(endpoints(), fn {label, call, accepted} ->
        log = capture_log(fn -> call.(accepted) end)

        refute log =~ "unknown option",
               "#{label} warned about its own documented options: #{log}"
      end)
    end

    test "Entitlement.list/1 accepts all eight of its filters", %{bypass: bypass} do
      Bypass.down(bypass)
      # This endpoint interpolates the application id, so the bot user has to be there.
      # It lives in :persistent_term, which outlives the test, so it is put back.
      previous = :persistent_term.get(:eda_current_user_raw, nil)
      EDA.Cache.put_me(%{"id" => "999", "username" => "eda"})

      on_exit(fn ->
        if previous,
          do: EDA.Cache.put_me(previous),
          else:
            :persistent_term.erase(:eda_current_user) &&
              :persistent_term.erase(:eda_current_user_raw)
      end)

      log =
        capture_log(fn ->
          assert {:error, _} =
                   EDA.API.Entitlement.list(
                     user_id: "1",
                     sku_ids: "2,3",
                     before: "4",
                     after: "5",
                     limit: 10,
                     guild_id: "6",
                     exclude_ended: true,
                     exclude_deleted: false
                   )
        end)

      refute log =~ "unknown option"
    end

    test "Member.search/3 keeps its own query parameter", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/guilds/111/members/search", fn conn ->
        assert URI.decode_query(conn.query_string) == %{"query" => "ada", "limit" => "5"}

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!([]))
      end)

      assert {:ok, []} = EDA.API.Member.search("111", "ada", limit: 5)
    end

    test "Guild.prune/2 takes a keyword list, which used to crash the encoder",
         %{bypass: bypass} do
      test_pid = self()

      Bypass.expect_once(bypass, "POST", "/guilds/111/prune", fn conn ->
        {:ok, raw, conn} = Plug.Conn.read_body(conn)

        send(
          test_pid,
          {:body, Jason.decode!(raw), Plug.Conn.get_req_header(conn, "x-audit-log-reason")}
        )

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(%{"pruned" => 3}))
      end)

      assert {:ok, %{"pruned" => 3}} =
               EDA.API.Guild.prune("111",
                 days: 30,
                 compute_prune_count: false,
                 include_roles: ["1"],
                 reason: "spring cleaning"
               )

      assert_receive {:body, body, [reason]}
      assert body == %{"days" => 30, "compute_prune_count" => false, "include_roles" => ["1"]}
      assert reason == URI.encode("spring cleaning")
    end

    test "Invite.create/2 warns about a misspelt option, and sends it anyway", %{bypass: bypass} do
      test_pid = self()

      Bypass.expect_once(bypass, "POST", "/channels/111/invites", fn conn ->
        {:ok, raw, conn} = Plug.Conn.read_body(conn)
        send(test_pid, {:body, Jason.decode!(raw)})

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(%{"code" => "abc"}))
      end)

      log = capture_log(fn -> assert {:ok, _} = EDA.API.Invite.create("111", max_ages: 3600) end)

      assert log =~ "EDA.API.Invite.create/2"
      assert log =~ "unknown option [:max_ages]"
      assert_receive {:body, %{"max_ages" => 3600}}
    end

    test "Invite.create/2 accepts every documented option silently", %{bypass: bypass} do
      Bypass.down(bypass)

      log =
        capture_log(fn ->
          EDA.API.Invite.create("111",
            max_age: 60,
            max_uses: 1,
            temporary: false,
            unique: true,
            target_type: 1,
            target_user_id: "1",
            target_application_id: "2",
            role_ids: ["3"]
          )
        end)

      refute log =~ "unknown option"
    end

    test "Guild.prune/2 warns about an unknown option — it is a destructive call",
         %{bypass: bypass} do
      # `day: 30` prunes on the default 7 days. The warning is the only signal the caller
      # gets that more members than intended are about to go.
      Bypass.down(bypass)

      log = capture_log(fn -> EDA.API.Guild.prune("111", day: 30) end)

      assert log =~ "unknown option [:day]"
      assert log =~ "EDA.API.Guild.prune/2"
    end

    test "no options at all is still a bare path", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/guilds/111/members", fn conn ->
        assert conn.query_string == ""

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!([]))
      end)

      assert {:ok, []} = EDA.API.Member.list("111")
    end
  end
end
