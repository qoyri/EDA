defmodule EDA.API.InviteTargetUsersTest do
  @moduledoc """
  Covers the target users endpoints and the CSV EDA writes and reads on the caller's behalf.

  Discord carries this list as a file rather than a JSON array, uploaded as
  `multipart/form-data` under the field name `target_users_file` — not the `files[n]`
  convention the rest of the API uses — and read back as `text/csv`. Both directions are
  asserted on the wire, because getting either wrong fails in a way the types cannot catch.
  """

  # NOT async — Bypass and the Application env are global.
  use ExUnit.Case

  alias EDA.API.Invite

  doctest EDA.API.Invite

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

  describe "to_csv/1" do
    test "writes the header Discord's own export carries" do
      assert Invite.to_csv(["123", "456"]) == "user_id\n123\n456\n"
    end

    test "integers are accepted, since snowflakes are often held as ints" do
      assert Invite.to_csv([123, 456]) == "user_id\n123\n456\n"
    end

    test "an empty list is a valid file, meaning 'nobody'" do
      assert Invite.to_csv([]) == "user_id\n"
    end

    test "a CSV already in hand passes through untouched" do
      csv = "user_id\r\n999\r\n"
      assert Invite.to_csv(csv) == csv
    end
  end

  describe "parse_csv/1" do
    test "reads what to_csv/1 writes" do
      assert ["123", "456"] |> Invite.to_csv() |> Invite.parse_csv() == ["123", "456"]
    end

    test "tolerates CRLF, blank lines and a trailing comma" do
      assert Invite.parse_csv("user_id\r\n123,\r\n\r\n456\r\n") == ["123", "456"]
    end

    test "a file with no header still parses" do
      assert Invite.parse_csv("123\n456") == ["123", "456"]
    end

    test "an empty body is an empty list, not a crash" do
      assert Invite.parse_csv("") == []
      assert Invite.parse_csv("user_id\n") == []
    end
  end

  describe "job_status/1" do
    test "names every documented value" do
      assert Invite.job_status(0) == :unspecified
      assert Invite.job_status(1) == :processing
      assert Invite.job_status(2) == :completed
      assert Invite.job_status(3) == :failed
    end

    test "an unknown or absent status does not crash a poller" do
      assert Invite.job_status(99) == :unknown
      assert Invite.job_status(nil) == :unknown
    end
  end

  describe "target_users/1" do
    test "parses the CSV Discord returns into ids", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/invites/abc123/target-users", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("text/csv")
        |> Plug.Conn.resp(200, "user_id\n80351110224678912\n82198898841029460\n")
      end)

      assert {:ok, ["80351110224678912", "82198898841029460"]} = Invite.target_users("abc123")
    end

    test "an invite that never had a list reads as empty, not as an error",
         %{bypass: bypass} do
      # 10129 is "unknown invite target users" — a legitimate state for a plain invite.
      Bypass.expect_once(bypass, "GET", "/invites/abc123/target-users", fn conn ->
        json(conn, %{"code" => 10_129, "message" => "Unknown invite target users"}, 404)
      end)

      assert {:ok, []} = Invite.target_users("abc123")
    end

    test "any other error is still an error", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/invites/abc123/target-users", fn conn ->
        json(conn, %{"code" => 50_013, "message" => "Missing Permissions"}, 403)
      end)

      assert {:error, %{code: 50_013}} = Invite.target_users("abc123")
    end
  end

  describe "update_target_users/2" do
    test "PUTs a multipart body with the field name Discord expects", %{bypass: bypass} do
      test_pid = self()

      Bypass.expect_once(bypass, "PUT", "/invites/abc123/target-users", fn conn ->
        {:ok, raw, conn} = Plug.Conn.read_body(conn)
        send(test_pid, {:body, raw, Plug.Conn.get_req_header(conn, "content-type")})
        json(conn, %{"code" => "abc123"})
      end)

      assert {:ok, _} = Invite.update_target_users("abc123", ["80351110224678912"])

      assert_receive {:body, body, [content_type]}
      assert content_type =~ "multipart/form-data; boundary="

      # the named field, NOT the files[n] convention used for message attachments
      assert body =~ ~s(name="target_users_file")
      assert body =~ ~s(filename="target_users.csv")
      assert body =~ "Content-Type: text/csv"
      # the CSV itself is LF-separated; the \r\n above are multipart delimiters
      assert body =~ "user_id\n80351110224678912\n"
      refute body =~ "files[0]"
      # no message payload rides along
      refute body =~ "payload_json"
    end

    test "an empty list clears the restriction", %{bypass: bypass} do
      test_pid = self()

      Bypass.expect_once(bypass, "PUT", "/invites/abc123/target-users", fn conn ->
        {:ok, raw, conn} = Plug.Conn.read_body(conn)
        send(test_pid, {:body, raw})
        json(conn, %{"code" => "abc123"})
      end)

      assert {:ok, _} = Invite.update_target_users("abc123", [])

      assert_receive {:body, body}
      assert body =~ "user_id"
    end

    test "a CSV binary is sent as given", %{bypass: bypass} do
      test_pid = self()

      Bypass.expect_once(bypass, "PUT", "/invites/abc123/target-users", fn conn ->
        {:ok, raw, conn} = Plug.Conn.read_body(conn)
        send(test_pid, {:body, raw})
        json(conn, %{"code" => "abc123"})
      end)

      assert {:ok, _} = Invite.update_target_users("abc123", "user_id\n777\n")

      assert_receive {:body, body}
      assert body =~ "user_id\n777"
    end
  end

  describe "target_users_job_status/1" do
    test "replaces the status integer with a name, keeping the rest", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/invites/abc123/target-users/job-status", fn conn ->
        json(conn, %{
          "status" => 1,
          "total_users" => 400,
          "processed_users" => 120,
          "created_at" => "2026-09-19T12:00:00Z",
          "completed_at" => nil,
          "error_message" => nil
        })
      end)

      assert {:ok, status} = Invite.target_users_job_status("abc123")

      assert status.status == :processing
      assert status["total_users"] == 400
      assert status["processed_users"] == 120
      # the raw integer is still there for anyone who wants it
      assert status["status"] == 1
    end

    test "a failed job carries its message", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/invites/abc123/target-users/job-status", fn conn ->
        json(conn, %{"status" => 3, "error_message" => "invalid user id on line 4"})
      end)

      assert {:ok, %{"error_message" => "invalid user id on line 4", status: :failed}} =
               Invite.target_users_job_status("abc123")
    end

    test "an error passes through untouched", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/invites/abc123/target-users/job-status", fn conn ->
        json(conn, %{"code" => 10_124, "message" => "Unknown invite target users job"}, 404)
      end)

      assert {:error, %{code: 10_124}} = Invite.target_users_job_status("abc123")
    end
  end

  describe "create/2 with the new params" do
    test "role_ids rides in the JSON body", %{bypass: bypass} do
      test_pid = self()

      Bypass.expect_once(bypass, "POST", "/channels/111/invites", fn conn ->
        {:ok, raw, conn} = Plug.Conn.read_body(conn)
        send(test_pid, {:body, Jason.decode!(raw)})
        json(conn, %{"code" => "abc"})
      end)

      assert {:ok, _} = Invite.create("111", max_uses: 1, role_ids: ["41771983423143936"])

      assert_receive {:body, body}
      assert body["role_ids"] == ["41771983423143936"]
      assert body["max_uses"] == 1
    end

    test "target_users turns the request into multipart with payload_json alongside",
         %{bypass: bypass} do
      test_pid = self()

      Bypass.expect_once(bypass, "POST", "/channels/111/invites", fn conn ->
        {:ok, raw, conn} = Plug.Conn.read_body(conn)
        send(test_pid, {:body, raw, Plug.Conn.get_req_header(conn, "content-type")})
        json(conn, %{"code" => "abc"})
      end)

      assert {:ok, _} =
               Invite.create("111",
                 max_uses: 1,
                 role_ids: ["41771983423143936"],
                 target_users: ["80351110224678912"]
               )

      assert_receive {:body, body, [content_type]}
      assert content_type =~ "multipart/form-data"

      # the non-file params travel as payload_json, per Discord's multipart rules
      assert body =~ "payload_json"
      assert body =~ ~s(name="target_users_file")
      assert body =~ "80351110224678912"

      [_, json_part] = Regex.run(~r/name="payload_json".*?\r\n\r\n(.*?)\r\n--/s, body)
      payload = Jason.decode!(json_part)
      assert payload["max_uses"] == 1
      assert payload["role_ids"] == ["41771983423143936"]
      refute Map.has_key?(payload, "target_users")
    end

    test "the reason becomes a header on the multipart request too", %{bypass: bypass} do
      test_pid = self()

      Bypass.expect_once(bypass, "POST", "/channels/111/invites", fn conn ->
        send(test_pid, {:reason, Plug.Conn.get_req_header(conn, "x-audit-log-reason")})
        json(conn, %{"code" => "abc"})
      end)

      assert {:ok, _} = Invite.create("111", target_users: ["1"], reason: "guest list")

      assert_receive {:reason, [reason]}
      assert reason == URI.encode("guest list")
    end

    test "the reason never leaks into the JSON body", %{bypass: bypass} do
      test_pid = self()

      Bypass.expect_once(bypass, "POST", "/channels/111/invites", fn conn ->
        {:ok, raw, conn} = Plug.Conn.read_body(conn)
        send(test_pid, {:body, Jason.decode!(raw)})
        json(conn, %{"code" => "abc"})
      end)

      assert {:ok, _} = Invite.create("111", max_uses: 1, reason: "spring cleaning")

      assert_receive {:body, body}
      refute Map.has_key?(body, "reason")
    end

    test "the map form supports the same options", %{bypass: bypass} do
      test_pid = self()

      Bypass.expect_once(bypass, "POST", "/channels/111/invites", fn conn ->
        {:ok, raw, conn} = Plug.Conn.read_body(conn)
        send(test_pid, {:body, raw})
        json(conn, %{"code" => "abc"})
      end)

      assert {:ok, _} = Invite.create("111", %{max_uses: 1, target_users: ["7"]})

      assert_receive {:body, body}
      assert body =~ ~s(name="target_users_file")
    end
  end

  describe "unknown options are refused, not forwarded" do
    test "create/2 names the offending key and what it accepts", %{bypass: bypass} do
      # Discord ignores a body field it does not recognise, so `max_ages: 3600` would
      # silently give the default 24-hour invite while looking like it asked for an hour.
      Bypass.down(bypass)

      error = assert_raise(ArgumentError, fn -> Invite.create("111", max_ages: 3600) end)

      assert error.message =~ "unknown option [:max_ages]"
      assert error.message =~ ":max_age"
      assert error.message =~ ":role_ids"
    end

    test "get/2 rejects a misspelt query option", %{bypass: bypass} do
      Bypass.down(bypass)

      assert_raise ArgumentError, ~r/unknown option \[:with_count\]/, fn ->
        Invite.get("abc123", with_count: true)
      end
    end

    test "several unknown keys are reported together", %{bypass: bypass} do
      Bypass.down(bypass)

      assert_raise ArgumentError, ~r/unknown options \[:bar, :foo\]/, fn ->
        Invite.create("111", foo: 1, bar: 2)
      end
    end

    test "the map form is checked too", %{bypass: bypass} do
      Bypass.down(bypass)

      assert_raise ArgumentError, ~r/unknown option \[:nope\]/, fn ->
        Invite.create("111", %{nope: 1})
      end
    end

    test "every documented option is accepted", %{bypass: bypass} do
      Bypass.down(bypass)

      opts = [
        max_age: 3600,
        max_uses: 1,
        temporary: false,
        unique: true,
        target_type: 1,
        target_user_id: "1",
        target_application_id: "2",
        role_ids: ["3"],
        reason: "because"
      ]

      # Reaching the transport proves validation let everything through.
      assert {:error, _} = Invite.create("111", opts)
      assert {:error, _} = Invite.get("abc", with_counts: true, guild_scheduled_event_id: "1")
    end
  end

  describe "get/2" do
    test "GET /invites/:code with query options", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/invites/abc123", fn conn ->
        conn = Plug.Conn.fetch_query_params(conn)
        assert conn.query_params["with_counts"] == "true"
        json(conn, %{"code" => "abc123", "approximate_member_count" => 42})
      end)

      assert {:ok, %{"approximate_member_count" => 42}} =
               Invite.get("abc123", with_counts: true)
    end

    test "no options means a bare path", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/invites/abc123", fn conn ->
        assert conn.query_string == ""
        json(conn, %{"code" => "abc123"})
      end)

      assert {:ok, _} = Invite.get("abc123")
    end
  end

  describe "delete/2" do
    test "carries an audit log reason", %{bypass: bypass} do
      test_pid = self()

      Bypass.expect_once(bypass, "DELETE", "/invites/abc123", fn conn ->
        send(test_pid, {:reason, Plug.Conn.get_req_header(conn, "x-audit-log-reason")})
        json(conn, %{"code" => "abc123"})
      end)

      assert {:ok, _} = Invite.delete("abc123", reason: "revoked")

      assert_receive {:reason, [reason]}
      assert reason == "revoked"
    end
  end
end
