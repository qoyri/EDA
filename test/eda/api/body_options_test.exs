defmodule EDA.API.BodyOptionsTest do
  @moduledoc """
  What reaches Discord's request body, for every route built from options.

  The keyword path of every message send went through a builder that kept five named keys
  and **dropped the rest**. `allowed_mentions` was among the dropped: a bot echoing user
  text with `allowed_mentions: %{parse: []}` to neutralise `@everyone` pinged everyone
  anyway. `flags: 4096` — a silent message — notified the channel. On webhooks, `username`
  and `avatar_url` never arrived, which is most of the point of a webhook.

  These tests assert the body on the wire, because each of those failures returned
  `{:ok, message}`. An option a route does not define is reported with a warning and still
  sent, so a patch release never stops a call that works; 0.5 will refuse it.
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

  defp capture(bypass, method, path, response \\ %{"id" => "1"}) do
    test_pid = self()

    Bypass.expect_once(bypass, method, path, fn conn ->
      {:ok, raw, conn} = Plug.Conn.read_body(conn)
      body = if raw == "", do: %{}, else: Jason.decode!(raw)
      send(test_pid, {:captured, body, conn.query_string})

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.resp(200, Jason.encode!(response))
    end)
  end

  describe "message create — the fields that used to be dropped" do
    test "allowed_mentions reaches Discord, so @everyone can be neutralised", %{bypass: bypass} do
      capture(bypass, "POST", "/channels/111/messages")

      assert {:ok, _} =
               EDA.API.Message.create("111",
                 content: "@everyone you won",
                 allowed_mentions: %{parse: []}
               )

      assert_receive {:captured, body, _}
      assert body["allowed_mentions"] == %{"parse" => []}
    end

    test "flags, tts, sticker_ids, message_reference and nonce all arrive", %{bypass: bypass} do
      capture(bypass, "POST", "/channels/111/messages")

      assert {:ok, _} =
               EDA.API.Message.create("111",
                 content: "hi",
                 flags: 4096,
                 tts: true,
                 sticker_ids: ["9"],
                 message_reference: %{message_id: "5"},
                 nonce: "n1",
                 enforce_nonce: true
               )

      assert_receive {:captured, body, _}
      assert body["flags"] == 4096
      assert body["tts"] == true
      assert body["sticker_ids"] == ["9"]
      assert body["message_reference"] == %{"message_id" => "5"}
      assert body["nonce"] == "n1"
      assert body["enforce_nonce"] == true
    end

    test "v2 combines with explicit flags instead of overwriting them", %{bypass: bypass} do
      # 32768 (components v2) | 4096 (suppress notifications). Overwriting would quietly
      # turn a silent message into a noisy one.
      capture(bypass, "POST", "/channels/111/messages")

      assert {:ok, _} = EDA.API.Message.create("111", v2: true, flags: 4096)

      assert_receive {:captured, body, _}
      assert body["flags"] == 32_768 + 4096
    end

    test "v2 alone still sets the components-v2 flag", %{bypass: bypass} do
      capture(bypass, "POST", "/channels/111/messages")

      assert {:ok, _} = EDA.API.Message.create("111", v2: true, components: [])

      assert_receive {:captured, body, _}
      assert body["flags"] == 32_768
    end

    test "EDA's own keys are interpreted, not forwarded", %{bypass: bypass} do
      capture(bypass, "POST", "/channels/111/messages")

      assert {:ok, _} = EDA.API.Message.create("111", embed: %{title: "t"}, v2: false)

      assert_receive {:captured, body, _}
      assert body["embeds"] == [%{"title" => "t"}]
      refute Map.has_key?(body, "embed")
      refute Map.has_key?(body, "v2")
    end
  end

  describe "message routes warn about what they do not define" do
    setup %{bypass: bypass} do
      Bypass.down(bypass)
      :ok
    end

    test "create warns about a misspelt key, naming the function" do
      log =
        capture_log(fn ->
          EDA.API.Message.create("111", content: "x", allowed_mention: %{parse: []})
        end)

      assert log =~ "EDA.API.Message.create/2"
      assert log =~ "unknown option [:allowed_mention]"
      assert log =~ ":allowed_mentions"
    end

    test "edit warns about fields Discord only accepts on create" do
      # tts and sticker_ids are create-only; Discord ignores them on an edit.
      assert capture_log(fn -> EDA.API.Message.edit("111", "222", content: "x", tts: true) end) =~
               "unknown option [:tts]"

      assert capture_log(fn -> EDA.API.Message.edit("111", "222", sticker_ids: ["1"]) end) =~
               "unknown option [:sticker_ids]"
    end

    test "reply warns about a misspelt key" do
      log =
        capture_log(fn -> EDA.API.Message.reply(%{channel_id: "111", id: "222"}, contnet: "x") end)

      assert log =~ "EDA.API.Message.reply/2"
      assert log =~ "unknown option [:contnet]"
    end

    test "a correct call warns about nothing" do
      log =
        capture_log(fn ->
          EDA.API.Message.create("111",
            content: "x",
            allowed_mentions: %{parse: []},
            flags: 4096,
            embed: %{title: "t"},
            delete_after: 5_000
          )
        end)

      refute log =~ "unknown option"
    end
  end

  describe "an unknown key is still sent" do
    test "so a field EDA does not list yet still reaches Discord", %{bypass: bypass} do
      capture(bypass, "POST", "/channels/111/messages")

      log =
        capture_log(fn ->
          assert {:ok, _} = EDA.API.Message.create("111", content: "x", brand_new_field: true)
        end)

      assert_receive {:captured, body, _}
      assert body["brand_new_field"] == true
      assert log =~ "unknown option [:brand_new_field]"
    end
  end

  describe "message edit keeps what it accepts" do
    test "allowed_mentions and flags reach the edit too", %{bypass: bypass} do
      capture(bypass, "PATCH", "/channels/111/messages/222")

      assert {:ok, _} =
               EDA.API.Message.edit("111", "222",
                 content: "edited",
                 flags: 4,
                 allowed_mentions: %{parse: ["users"]}
               )

      assert_receive {:captured, body, _}
      assert body["flags"] == 4
      assert body["allowed_mentions"] == %{"parse" => ["users"]}
    end
  end

  describe "webhook execute" do
    test "username, avatar_url and thread_name arrive in the body", %{bypass: bypass} do
      capture(bypass, "POST", "/webhooks/1/tok")

      assert {:ok, _} =
               EDA.API.Webhook.execute("1", "tok",
                 content: "hello",
                 username: "Deploy Bot",
                 avatar_url: "https://example.com/a.png",
                 thread_name: "Release notes",
                 allowed_mentions: %{parse: []}
               )

      assert_receive {:captured, body, _query}
      assert body["username"] == "Deploy Bot"
      assert body["avatar_url"] == "https://example.com/a.png"
      assert body["thread_name"] == "Release notes"
      assert body["allowed_mentions"] == %{"parse" => []}
    end

    test "thread_id goes to the query string, not the body", %{bypass: bypass} do
      # In the body Discord would ignore it and post to the parent channel instead.
      capture(bypass, "POST", "/webhooks/1/tok")

      assert {:ok, _} = EDA.API.Webhook.execute("1", "tok", content: "x", thread_id: "777")

      assert_receive {:captured, body, query}
      assert URI.decode_query(query)["thread_id"] == "777"
      refute Map.has_key?(body, "thread_id")
    end

    test "wait: true still asks for the message back, and wait: false is not sent",
         %{bypass: bypass} do
      capture(bypass, "POST", "/webhooks/1/tok")
      assert {:ok, _} = EDA.API.Webhook.execute("1", "tok", content: "x", wait: true)
      assert_receive {:captured, body, query}
      assert URI.decode_query(query)["wait"] == "true"
      refute Map.has_key?(body, "wait")

      capture(bypass, "POST", "/webhooks/1/tok")
      assert {:ok, _} = EDA.API.Webhook.execute("1", "tok", content: "x", wait: false)
      assert_receive {:captured, _body, ""}
    end

    test "the map form routes the query keys the same way", %{bypass: bypass} do
      capture(bypass, "POST", "/webhooks/1/tok")

      assert {:ok, _} =
               EDA.API.Webhook.execute("1", "tok", %{content: "x", thread_id: "7", wait: true})

      assert_receive {:captured, body, query}
      assert URI.decode_query(query) == %{"thread_id" => "7", "wait" => "true"}
      assert body == %{"content" => "x"}
    end

    test "an unknown key is reported", %{bypass: bypass} do
      Bypass.down(bypass)

      log =
        capture_log(fn -> EDA.API.Webhook.execute("1", "tok", content: "x", user_name: "Bob") end)

      assert log =~ "EDA.API.Webhook.execute/3"
      assert log =~ "unknown option [:user_name]"
    end
  end

  describe "webhook edit_message" do
    test "thread_id goes to the query, the rest to the body", %{bypass: bypass} do
      capture(bypass, "PATCH", "/webhooks/1/tok/messages/9")

      assert {:ok, _} =
               EDA.API.Webhook.edit_message("1", "tok", "9",
                 content: "edited",
                 thread_id: "777",
                 allowed_mentions: %{parse: []}
               )

      assert_receive {:captured, body, query}
      assert URI.decode_query(query)["thread_id"] == "777"
      assert body["content"] == "edited"
      assert body["allowed_mentions"] == %{"parse" => []}
      refute Map.has_key?(body, "thread_id")
    end

    test "execute-only fields are reported on an edit", %{bypass: bypass} do
      Bypass.down(bypass)

      log = capture_log(fn -> EDA.API.Webhook.edit_message("1", "tok", "9", username: "Bob") end)

      assert log =~ "EDA.API.Webhook.edit_message/4"
      assert log =~ "unknown option [:username]"
    end
  end

  describe "the smaller bodies" do
    setup %{bypass: bypass} do
      Bypass.down(bypass)
      :ok
    end

    test "each warns about an unknown key and names what it accepts" do
      cases = [
        {"EDA.API.Webhook.create/2", fn -> EDA.API.Webhook.create("1", name: "x", avatr: "y") end,
         ":avatar"},
        {"EDA.API.Webhook.modify/2", fn -> EDA.API.Webhook.modify("1", chanel_id: "2") end,
         ":channel_id"},
        {"EDA.API.Thread.start_from_message/3",
         fn -> EDA.API.Thread.start_from_message("1", "2", name: "t", auto_archive: 60) end,
         ":auto_archive_duration"},
        {"EDA.API.Thread.start/2",
         fn -> EDA.API.Thread.start("1", name: "t", invitible: false) end, ":invitable"},
        {"EDA.API.Thread.create_post/3",
         fn -> EDA.API.Thread.create_post("1", [name: "t", tags: ["a"]], content: "x") end,
         ":applied_tags"},
        {"EDA.API.Thread.create_post/3 (message)",
         fn -> EDA.API.Thread.create_post("1", [name: "t"], contnet: "x") end, ":content"},
        {"EDA.API.Channel.edit_permissions/3",
         fn -> EDA.API.Channel.edit_permissions("1", "2", alow: "8", type: 0) end, ":allow"},
        {"EDA.API.User.modify_me/1", fn -> EDA.API.User.modify_me(user_name: "x") end,
         ":username"},
        {"EDA.API.Entitlement.create_test/1",
         fn -> EDA.API.Entitlement.create_test(sku_id: "1", owner: "2", owner_type: 2) end,
         ":owner_id"}
      ]

      # create_test interpolates the application id, so the bot user has to exist. It lives
      # in :persistent_term, which outlives the test, so it is put back.
      previous = :persistent_term.get(:eda_current_user_raw, nil)
      EDA.Cache.put_me(%{"id" => "999", "username" => "eda"})

      on_exit(fn ->
        if previous,
          do: EDA.Cache.put_me(previous),
          else:
            :persistent_term.erase(:eda_current_user) &&
              :persistent_term.erase(:eda_current_user_raw)
      end)

      for {label, call, expected_hint} <- cases do
        log = capture_log(call)

        assert log =~ label, "#{label} should name itself: #{log}"
        assert log =~ "unknown option", "#{label} did not warn: #{log}"
        assert log =~ expected_hint, "#{label} should name #{expected_hint}"
      end
    end
  end

  describe "the smaller bodies accept keyword lists, which used to crash the encoder" do
    test "Channel.edit_permissions", %{bypass: bypass} do
      Bypass.expect_once(bypass, "PUT", "/channels/1/permissions/2", fn conn ->
        {:ok, raw, conn} = Plug.Conn.read_body(conn)
        assert Jason.decode!(raw) == %{"allow" => "8", "deny" => "0", "type" => 0}
        Plug.Conn.resp(conn, 204, "")
      end)

      assert :ok = EDA.API.Channel.edit_permissions("1", "2", allow: "8", deny: "0", type: 0)
    end

    test "Thread.start and Webhook.create", %{bypass: bypass} do
      capture(bypass, "POST", "/channels/1/threads")
      assert {:ok, _} = EDA.API.Thread.start("1", name: "t", type: 11, invitable: false)
      assert_receive {:captured, %{"name" => "t", "type" => 11, "invitable" => false}, _}

      capture(bypass, "POST", "/channels/1/webhooks")
      assert {:ok, _} = EDA.API.Webhook.create("1", name: "hook")
      assert_receive {:captured, %{"name" => "hook"}, _}
    end

    test "the map form still works unchanged", %{bypass: bypass} do
      capture(bypass, "PATCH", "/users/@me")
      assert {:ok, _} = EDA.API.User.modify_me(%{username: "eda"})
      assert_receive {:captured, %{"username" => "eda"}, _}
    end
  end
end
