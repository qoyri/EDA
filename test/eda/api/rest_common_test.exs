defmodule EDA.API.RestCommonTest do
  @moduledoc """
  REST routes the 2026-09-21 audit of Discord's reference found missing: the bot's guilds and
  leaving one, publishing and following announcements, archived threads, application emojis.
  """

  # NOT async — Bypass, the Application env and the cached bot user are global.
  use ExUnit.Case

  setup do
    bypass = Bypass.open()
    Application.put_env(:eda, :base_url, "http://localhost:#{bypass.port}")
    Application.put_env(:eda, :token, "test-token")
    on_exit(fn -> Application.delete_env(:eda, :base_url) end)
    {:ok, bypass: bypass}
  end

  defp capture(bypass, method, path, response, status \\ 200) do
    test_pid = self()

    Bypass.expect(bypass, method, path, fn conn ->
      {:ok, raw, conn} = Plug.Conn.read_body(conn)
      body = if raw == "", do: nil, else: Jason.decode!(raw)

      send(
        test_pid,
        {:captured, URI.decode_query(conn.query_string), body,
         Plug.Conn.get_req_header(conn, "x-audit-log-reason")}
      )

      if status == 204 do
        Plug.Conn.resp(conn, 204, "")
      else
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(status, Jason.encode!(response))
      end
    end)
  end

  describe "the bot's guilds" do
    test "guilds/1 passes its filters, shard included", %{bypass: bypass} do
      capture(bypass, "GET", "/users/@me/guilds", [%{"id" => "1"}])

      assert {:ok, [_]} = EDA.API.User.guilds(with_counts: true, shard: 0, limit: 50)

      assert_receive {:captured, %{"with_counts" => "true", "shard" => "0", "limit" => "50"}, nil,
                      _}

      assert_raise ArgumentError, ~r/unknown option \[:shards\]/, fn ->
        EDA.API.User.guilds(shards: 1)
      end
    end

    test "stream_guilds/1 pages by id, 200 at a time", %{bypass: bypass} do
      first = for i <- 1..200, do: %{"id" => Integer.to_string(1000 + i)}

      Bypass.expect(bypass, "GET", "/users/@me/guilds", fn conn ->
        page =
          case URI.decode_query(conn.query_string) do
            %{"after" => "1200", "limit" => "200"} -> [%{"id" => "1201"}]
            %{"limit" => "200"} -> first
          end

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(page))
      end)

      assert Enum.count(EDA.API.User.stream_guilds()) == 201
    end

    test "leave_guild/1 and EDA.Guild.leave/1", %{bypass: bypass} do
      capture(bypass, "DELETE", "/users/@me/guilds/7", nil, 204)
      assert :ok = EDA.API.User.leave_guild("7")
      assert :ok = EDA.Guild.leave(%EDA.Guild{id: "7"})
    end
  end

  describe "announcements" do
    test "crosspost/2, and EDA.Message.crosspost/1 returning a struct", %{bypass: bypass} do
      capture(bypass, "POST", "/channels/1/messages/2/crosspost", %{
        "id" => "2",
        "channel_id" => "1"
      })

      assert {:ok, %{"id" => "2"}} = EDA.API.Message.crosspost("1", "2")

      assert {:ok, %EDA.Message{id: "2"}} =
               EDA.Message.crosspost(%EDA.Message{channel_id: "1", id: "2"})
    end

    test "follow/3 sends the target channel and the audit reason", %{bypass: bypass} do
      capture(bypass, "POST", "/channels/1/followers", %{"channel_id" => "1", "webhook_id" => "9"})

      assert {:ok, %{"webhook_id" => "9"}} =
               EDA.Channel.follow(%EDA.Channel{id: "1"}, %EDA.Channel{id: 5}, reason: "news")

      assert_receive {:captured, _, %{"webhook_channel_id" => "5"}, ["news"]}
    end
  end

  describe "archived threads" do
    test "the three routes, with a DateTime before for the timed ones", %{bypass: bypass} do
      envelope = %{"threads" => [], "members" => [], "has_more" => false}
      capture(bypass, "GET", "/channels/1/threads/archived/public", envelope)
      capture(bypass, "GET", "/channels/1/threads/archived/private", envelope)
      capture(bypass, "GET", "/channels/1/users/@me/threads/archived/private", envelope)

      assert {:ok, ^envelope} =
               EDA.API.Thread.list_public_archived("1",
                 before: ~U[2026-09-01 00:00:00Z],
                 limit: 5
               )

      assert_receive {:captured, %{"before" => "2026-09-01T00:00:00Z", "limit" => "5"}, _, _}

      assert {:ok, _} = EDA.API.Thread.list_private_archived("1")
      assert {:ok, _} = EDA.API.Thread.list_joined_private_archived("1", before: "123")
      assert_receive {:captured, %{}, _, _}
      assert_receive {:captured, %{"before" => "123"}, _, _}
    end

    test "stream_archived/3 pages on the archive time, or on the id for joined threads",
         %{bypass: bypass} do
      thread = fn id, ts -> %{"id" => id, "thread_metadata" => %{"archive_timestamp" => ts}} end

      Bypass.expect(bypass, "GET", "/channels/1/threads/archived/public", fn conn ->
        threads =
          case URI.decode_query(conn.query_string) do
            %{"before" => "2026-09-02T00:00:00Z"} -> [thread.("3", "2026-09-01T00:00:00Z")]
            _ -> [thread.("1", "2026-09-03T00:00:00Z"), thread.("2", "2026-09-02T00:00:00Z")]
          end

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(%{"threads" => threads, "has_more" => true}))
      end)

      ids = EDA.API.Thread.stream_archived("1", :public, per_page: 2) |> Enum.map(& &1["id"])
      assert ids == ["1", "2", "3"]
    end

    test "unknown options are refused" do
      assert_raise ArgumentError, ~r/list_public_archived\/2: unknown option \[:after\]/, fn ->
        EDA.API.Thread.list_public_archived("1", after: "x")
      end
    end
  end

  describe "application emojis" do
    setup do
      previous = :persistent_term.get(:eda_current_user_raw, nil)
      EDA.Cache.put_me(%{"id" => "999", "username" => "eda"})

      on_exit(fn ->
        if previous,
          do: EDA.Cache.put_me(previous),
          else:
            :persistent_term.erase(:eda_current_user) &&
              :persistent_term.erase(:eda_current_user_raw)
      end)
    end

    test "list unwraps Discord's items envelope", %{bypass: bypass} do
      capture(bypass, "GET", "/applications/999/emojis", %{
        "items" => [%{"id" => "5", "name" => "lul"}]
      })

      assert {:ok, [%EDA.Emoji{id: "5", name: "lul"}]} = EDA.Emoji.list_application()
    end

    test "create takes raw image bytes and sends image data", %{bypass: bypass} do
      capture(bypass, "POST", "/applications/999/emojis", %{"id" => "5", "name" => "lul"})
      png = <<0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0, 0>>

      assert {:ok, %EDA.Emoji{id: "5"}} = EDA.Emoji.create_application("lul", png)

      assert_receive {:captured, _, %{"name" => "lul", "image" => "data:image/png;base64," <> _},
                      _}
    end

    test "rename, get and delete", %{bypass: bypass} do
      capture(bypass, "PATCH", "/applications/999/emojis/5", %{"id" => "5", "name" => "kek"})
      capture(bypass, "GET", "/applications/999/emojis/5", %{"id" => "5", "name" => "kek"})
      capture(bypass, "DELETE", "/applications/999/emojis/5", nil, 204)

      assert {:ok, %EDA.Emoji{name: "kek"}} = EDA.Emoji.rename_application("5", "kek")
      assert_receive {:captured, _, %{"name" => "kek"}, _}
      assert {:ok, %EDA.Emoji{id: "5"}} = EDA.Emoji.fetch_application("5")
      assert :ok = EDA.Emoji.delete_application("5")
    end
  end
end
