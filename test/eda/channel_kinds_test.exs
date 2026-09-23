defmodule EDA.ChannelKindsTest do
  @moduledoc """
  What only one kind of channel has lives in `thread`, `forum`, `voice` or `dm`.

  Keeping every field flat would take `EDA.Channel` past 31 fields, where a map leaves its
  compact form: measured at about 3.5 times the memory for the struct itself, on the entity the
  cache holds by the thousand. The channel and thread events deliver this struct too; they used
  to carry a copy of 10 or 12 fields, so a change to a forum's tags was invisible.
  """

  use ExUnit.Case, async: true

  alias EDA.Channel

  describe "each kind gets its own part" do
    test "a thread: its metadata flattened, the bot's membership, the post's tags" do
      channel =
        Channel.from_raw(%{
          "id" => "1",
          "type" => 11,
          "parent_id" => "2",
          "owner_id" => "3",
          "thread_metadata" => %{
            "archived" => true,
            "auto_archive_duration" => 60,
            "archive_timestamp" => "2026-09-23T10:00:00+00:00",
            "locked" => true,
            "invitable" => false,
            "create_timestamp" => "2026-09-22T10:00:00+00:00"
          },
          "member" => %{"id" => "1", "user_id" => "4", "join_timestamp" => "x", "flags" => 1},
          "newly_created" => true,
          "applied_tags" => ["5"]
        })

      assert %Channel.Thread{archived: true, locked: true, invitable: false} = channel.thread
      assert channel.thread.auto_archive_duration == 60
      assert %Channel.ThreadMember{user_id: "4", flags: 1} = channel.thread.member
      assert channel.thread.newly_created
      assert channel.thread.applied_tags == ["5"]
      assert channel.forum == nil and channel.voice == nil and channel.dm == nil
    end

    test "a voice or stage channel" do
      for type <- [2, 13] do
        channel =
          Channel.from_raw(%{
            "id" => "1",
            "type" => type,
            "bitrate" => 64_000,
            "user_limit" => 5,
            "rtc_region" => "rotterdam",
            "video_quality_mode" => 2,
            "status" => "raid"
          })

        assert %Channel.Voice{bitrate: 64_000, user_limit: 5, rtc_region: "rotterdam"} =
                 channel.voice

        assert channel.voice.video_quality_mode == 2
        assert channel.voice.status == "raid"
        assert channel.thread == nil
      end
    end

    test "a forum or media channel" do
      for type <- [15, 16] do
        channel =
          Channel.from_raw(%{
            "id" => "1",
            "type" => type,
            "available_tags" => [%{"id" => "7", "name" => "Bug"}],
            "default_sort_order" => 1
          })

        assert %Channel.Forum{available_tags: [%EDA.ForumTag{name: "Bug"}]} = channel.forum
        assert channel.forum.default_sort_order == 1
      end
    end

    test "a direct message or group DM, with its recipients as users" do
      channel =
        Channel.from_raw(%{
          "id" => "1",
          "type" => 3,
          "owner_id" => "9",
          "icon" => "abc",
          "application_id" => "8",
          "managed" => true,
          "recipients" => [%{"id" => "9", "username" => "someone"}]
        })

      assert %Channel.DM{icon: "abc", application_id: "8", managed: true} = channel.dm
      assert [%EDA.User{username: "someone"}] = channel.dm.recipients
      assert channel.owner_id == "9"
    end

    test "a partial thread with no type is recognised by its fields" do
      # A message's thread, or an interaction's resolved channel, may come without a type.
      channel = Channel.from_raw(%{"id" => "1", "thread_metadata" => %{"archived" => false}})
      assert %Channel.Thread{archived: false} = channel.thread
    end

    test "fields shared by several kinds stay on the channel" do
      channel =
        Channel.from_raw(%{
          "id" => "1",
          "type" => 0,
          "default_auto_archive_duration" => 1440,
          "default_thread_rate_limit_per_user" => 30,
          "last_message_id" => "2"
        })

      assert channel.default_auto_archive_duration == 1440
      assert channel.default_thread_rate_limit_per_user == 30
      assert channel.last_message_id == "2"
    end
  end

  describe "the channel and thread events deliver the channel itself" do
    test "CHANNEL_UPDATE shows a forum's new tags" do
      event =
        EDA.Event.from_raw("CHANNEL_UPDATE", %{
          "id" => "1",
          "type" => 15,
          "flags" => 16,
          "available_tags" => [%{"id" => "7", "name" => "Solved"}]
        })

      assert %Channel{flags: 16} = event
      assert [%EDA.ForumTag{name: "Solved"}] = event.forum.available_tags
    end

    for name <- ~w(CHANNEL_CREATE CHANNEL_DELETE THREAD_CREATE THREAD_UPDATE THREAD_DELETE) do
      test "#{name} is an EDA.Channel" do
        assert %Channel{id: "1"} = EDA.Event.from_raw(unquote(name), %{"id" => "1", "type" => 11})
      end
    end

    test "THREAD_CREATE says whether the thread is new" do
      event =
        EDA.Event.from_raw("THREAD_CREATE", %{
          "id" => "1",
          "type" => 11,
          "newly_created" => true,
          "member" => %{"user_id" => "4"}
        })

      assert event.thread.newly_created
      assert event.thread.member.user_id == "4"
    end

    test "THREAD_LIST_SYNC and THREAD_MEMBERS_UPDATE carry structs" do
      sync =
        EDA.Event.from_raw("THREAD_LIST_SYNC", %{
          "guild_id" => "1",
          "threads" => [%{"id" => "2", "type" => 11}],
          "members" => [%{"id" => "2", "user_id" => "3"}]
        })

      assert [%Channel{id: "2", thread: %Channel.Thread{}}] = sync.threads
      assert [%Channel.ThreadMember{user_id: "3"}] = sync.members

      update =
        EDA.Event.from_raw("THREAD_MEMBERS_UPDATE", %{
          "id" => "2",
          "added_members" => [%{"user_id" => "3", "member" => %{"nick" => "n"}}]
        })

      assert [%Channel.ThreadMember{member: %EDA.Member{nick: "n"}}] = update.added_members
    end
  end
end
