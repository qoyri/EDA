defmodule EDA.API.QueryOptionsTest do
  @moduledoc """
  Every endpoint that builds a query string declares the parameters Discord defines.

  Discord ignores a query parameter it does not recognise, so a misspelt filter does not
  fail — it silently changes the result, so an unknown key raises and nothing is sent. `limit`
  mistyped on a member listing would return the
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

  describe "an unknown option is refused" do
    test "at every query endpoint, naming the path", %{bypass: bypass} do
      # Bypass is down: were the check to let the call through, it would fail at the transport
      # rather than raise.
      Bypass.down(bypass)

      Enum.each(endpoints(), fn {label, call, _accepted} ->
        error = assert_raise ArgumentError, fn -> call.(nope: 1) end
        assert error.message =~ "unknown option [:nope]", "#{label}: #{error.message}"
      end)
    end

    test "the error lists what is accepted, and where", %{bypass: bypass} do
      Bypass.down(bypass)

      error = assert_raise ArgumentError, fn -> EDA.API.Member.list("111", limits: 10) end

      assert error.message =~ "[:limits]"
      assert error.message =~ ":limit"
      assert error.message =~ ":after"
      assert error.message =~ "/guilds/111/members"
    end

    test "several are reported together", %{bypass: bypass} do
      Bypass.down(bypass)

      assert_raise ArgumentError, ~r/unknown options \[:a, :b\]/, fn ->
        EDA.API.Message.list("111", a: 1, b: 2)
      end
    end

    test "nothing is sent", %{bypass: _bypass} do
      # No expectation is set: a request reaching Bypass would fail the test on exit.
      assert_raise ArgumentError, fn -> EDA.API.Member.list("111", limit: 5, brand_new: "x") end
    end
  end

  describe "every documented option is accepted" do
    test "no endpoint's set is too narrow — its own options are accepted",
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

    test "Invite.create/2 refuses a misspelt option" do
      # `max_ages: 3600` would give the default 24-hour invite while looking like one hour.
      error = assert_raise ArgumentError, fn -> EDA.API.Invite.create("111", max_ages: 3600) end

      assert error.message =~ "EDA.API.Invite.create/2"
      assert error.message =~ "unknown option [:max_ages]"
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

    test "Guild.prune/2 refuses an unknown option — it is a destructive call" do
      # `day: 30` would prune on the default 7 days, kicking more members than intended.
      error = assert_raise ArgumentError, fn -> EDA.API.Guild.prune("111", day: 30) end

      assert error.message =~ "unknown option [:day]"
      assert error.message =~ "EDA.API.Guild.prune/2"
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
