defmodule EDA.ChannelTest do
  use ExUnit.Case

  alias EDA.Channel

  describe "from_raw/1" do
    test "parses with nested permission overwrites" do
      raw = %{
        "id" => "ch1",
        "type" => 0,
        "name" => "general",
        "permission_overwrites" => [
          %{"id" => "r1", "type" => 0, "allow" => "1024", "deny" => "0"}
        ]
      }

      channel = Channel.from_raw(raw)
      assert %Channel{} = channel
      assert channel.id == "ch1"
      assert channel.name == "general"
      assert [%EDA.PermissionOverwrite{id: "r1", allow: "1024"}] = channel.permission_overwrites
    end

    test "handles nil permission_overwrites" do
      channel = Channel.from_raw(%{"id" => "ch1"})
      assert channel.permission_overwrites == nil
    end

    test "parses a full forum channel" do
      raw = %{
        "id" => "forum1",
        "type" => 15,
        "name" => "help-forum",
        "guild_id" => "g1",
        "last_message_id" => "msg1",
        "default_auto_archive_duration" => 1440,
        "flags" => 0,
        "default_reaction_emoji" => %{"emoji_id" => nil, "emoji_name" => "👍"},
        "default_thread_rate_limit_per_user" => 60,
        "default_sort_order" => 0,
        "default_forum_layout" => 1,
        "available_tags" => [
          %{
            "id" => "t1",
            "name" => "Bug",
            "moderated" => false,
            "emoji_id" => nil,
            "emoji_name" => "🐛"
          },
          %{
            "id" => "t2",
            "name" => "Feature",
            "moderated" => true,
            "emoji_id" => "99",
            "emoji_name" => nil
          }
        ]
      }

      channel = Channel.from_raw(raw)
      assert channel.type == 15
      assert channel.last_message_id == "msg1"
      assert channel.default_auto_archive_duration == 1440
      assert channel.flags == 0
      assert channel.default_reaction_emoji == %{"emoji_id" => nil, "emoji_name" => "👍"}
      assert channel.default_thread_rate_limit_per_user == 60
      assert channel.default_sort_order == 0
      assert channel.default_forum_layout == 1

      assert [%EDA.ForumTag{id: "t1", name: "Bug"}, %EDA.ForumTag{id: "t2", name: "Feature"}] =
               channel.available_tags
    end

    test "parses applied_tags on a thread" do
      raw = %{
        "id" => "thread1",
        "type" => 11,
        "applied_tags" => ["t1", "t2"],
        "thread_metadata" => %{
          "archived" => false,
          "auto_archive_duration" => 1440,
          "locked" => false
        },
        "owner_id" => "u1",
        "member_count" => 5,
        "message_count" => 42,
        "total_message_sent" => 50
      }

      channel = Channel.from_raw(raw)
      assert channel.applied_tags == ["t1", "t2"]

      assert channel.thread_metadata == %{
               "archived" => false,
               "auto_archive_duration" => 1440,
               "locked" => false
             }

      assert channel.owner_id == "u1"
      assert channel.member_count == 5
      assert channel.message_count == 42
      assert channel.total_message_sent == 50
    end

    test "forum fields default to nil when absent" do
      channel = Channel.from_raw(%{"id" => "ch1", "type" => 0})
      assert channel.available_tags == nil
      assert channel.applied_tags == nil
      assert channel.default_reaction_emoji == nil
      assert channel.default_forum_layout == nil
      assert channel.default_sort_order == nil
      assert channel.thread_metadata == nil
      assert channel.owner_id == nil
      assert channel.status == nil
    end

    test "parses voice channel status" do
      channel = Channel.from_raw(%{"id" => "vc1", "type" => 2, "status" => "gaming"})
      assert channel.status == "gaming"
    end
  end

  describe "type helpers" do
    test "forum?/1 returns true for type 15" do
      assert Channel.forum?(%Channel{type: 15})
      refute Channel.forum?(%Channel{type: 0})
    end

    test "media?/1 returns true for type 16" do
      assert Channel.media?(%Channel{type: 16})
      refute Channel.media?(%Channel{type: 0})
    end

    test "thread?/1 returns true for thread types" do
      assert Channel.thread?(%Channel{type: 10})
      assert Channel.thread?(%Channel{type: 11})
      assert Channel.thread?(%Channel{type: 12})
      refute Channel.thread?(%Channel{type: 0})
      refute Channel.thread?(%Channel{type: 15})
    end
  end

  describe "constants" do
    test "channel type constants" do
      assert Channel.type_guild_text() == 0
      assert Channel.type_dm() == 1
      assert Channel.type_guild_voice() == 2
      assert Channel.type_group_dm() == 3
      assert Channel.type_guild_category() == 4
      assert Channel.type_guild_news() == 5
      assert Channel.type_guild_news_thread() == 10
      assert Channel.type_guild_public_thread() == 11
      assert Channel.type_guild_private_thread() == 12
      assert Channel.type_guild_stage_voice() == 13
      assert Channel.type_guild_forum() == 15
      assert Channel.type_guild_media() == 16
    end

    test "layout constants" do
      assert Channel.layout_not_set() == 0
      assert Channel.layout_list_view() == 1
      assert Channel.layout_gallery_view() == 2
    end

    test "sort order constants" do
      assert Channel.sort_latest_activity() == 0
      assert Channel.sort_creation_date() == 1
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
    test "returns a Channel struct from REST", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/channels/fetch_test_ch", fn conn ->
        json(conn, %{"id" => "fetch_test_ch", "name" => "general", "type" => 0})
      end)

      assert {:ok, %Channel{id: "fetch_test_ch", name: "general"}} =
               Channel.fetch("fetch_test_ch")
    end
  end

  describe "modify/3" do
    test "returns a Channel struct", %{bypass: bypass} do
      Bypass.expect_once(bypass, "PATCH", "/channels/ch1", fn conn ->
        json(conn, %{"id" => "ch1", "name" => "renamed", "type" => 0})
      end)

      assert {:ok, %Channel{name: "renamed"}} = Channel.modify("ch1", %{name: "renamed"})
    end
  end

  describe "send_message/2" do
    test "returns a Message struct", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/channels/ch1/messages", fn conn ->
        json(conn, %{"id" => "msg1", "channel_id" => "ch1", "content" => "hello"})
      end)

      assert {:ok, %EDA.Message{id: "msg1", content: "hello"}} =
               Channel.send_message("ch1", %{content: "hello"})
    end
  end

  describe "set_voice_status/3" do
    test "returns :ok on 204 and accepts a channel struct", %{bypass: bypass} do
      Bypass.expect_once(bypass, "PUT", "/channels/vc1/voice-status", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        assert Jason.decode!(body) == %{"status" => "gaming"}
        Plug.Conn.resp(conn, 204, "")
      end)

      assert :ok = Channel.set_voice_status(%Channel{id: "vc1"}, "gaming")
    end

    test "accepts an id, sends null to clear, and forwards the audit reason", %{bypass: bypass} do
      Bypass.expect_once(bypass, "PUT", "/channels/vc1/voice-status", fn conn ->
        assert {"x-audit-log-reason", "cleanup"} in conn.req_headers
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        assert Jason.decode!(body) == %{"status" => nil}
        Plug.Conn.resp(conn, 204, "")
      end)

      assert :ok = Channel.set_voice_status("vc1", nil, reason: "cleanup")
    end
  end
end
