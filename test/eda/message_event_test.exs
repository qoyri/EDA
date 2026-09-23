defmodule EDA.MessageEventTest do
  @moduledoc """
  `MESSAGE_CREATE` and `MESSAGE_UPDATE` deliver an `EDA.Message` with every documented field.

  The events used to have a struct of their own, a partial copy of the message: it dropped the
  poll and the reactions — a poll arrived through the gateway without its poll — along with
  `webhook_id` (on 23 % of real messages sampled), `flags`, forwarded content and the rest, and
  `EDA.Message.reply/2` refused it with a `FunctionClauseError`.
  """

  # NOT async — the reply test uses Bypass and the Application env.
  use ExUnit.Case

  import Bitwise, only: [<<<: 2]

  @payload %{
    "id" => "1500000000000000001",
    "channel_id" => "1500000000000000002",
    "guild_id" => "1500000000000000003",
    "channel_type" => 0,
    "author" => %{"id" => "1500000000000000004", "username" => "hook"},
    "content" => "",
    "timestamp" => "2026-09-23T10:00:00.000000+00:00",
    "edited_timestamp" => nil,
    "tts" => false,
    "mention_everyone" => false,
    "mentions" => [],
    "mention_roles" => [],
    "attachments" => [],
    "embeds" => [],
    "pinned" => false,
    "type" => 0,
    "webhook_id" => "1500000000000000004",
    "application_id" => "1500000000000000005",
    "flags" => 1 <<< 14,
    "nonce" => "42",
    "position" => 7,
    "reactions" => [%{"count" => 2, "me" => false, "emoji" => %{"id" => nil, "name" => "👍"}}],
    "poll" => %{
      "question" => %{"text" => "Lunch?"},
      "answers" => [%{"answer_id" => 1, "poll_media" => %{"text" => "Pizza"}}],
      "expiry" => "2026-09-24T10:00:00.000000+00:00",
      "allow_multiselect" => false,
      "layout_type" => 1
    },
    "message_reference" => %{"type" => 1, "message_id" => "9", "channel_id" => "8"},
    "message_snapshots" => [%{"message" => %{"content" => "forwarded text", "type" => 0}}],
    "interaction_metadata" => %{"id" => "10", "type" => 2, "user" => %{"id" => "11"}},
    "thread" => %{"id" => "1500000000000000006", "type" => 11, "name" => "discussion"},
    "mention_channels" => [%{"id" => "12", "guild_id" => "3", "type" => 0, "name" => "news"}],
    "call" => %{"participants" => ["11"], "ended_timestamp" => nil},
    "role_subscription_data" => %{
      "role_subscription_listing_id" => "13",
      "tier_name" => "Gold",
      "total_months_subscribed" => 3,
      "is_renewal" => true
    }
  }

  for event <- ["MESSAGE_CREATE", "MESSAGE_UPDATE"] do
    test "#{event} is an EDA.Message, poll and reactions included" do
      msg = EDA.Event.from_raw(unquote(event), @payload)

      assert %EDA.Message{} = msg
      assert %EDA.Poll{question: "Lunch?"} = msg.poll
      assert [%EDA.Reaction{count: 2}] = msg.reactions
    end
  end

  test "the fields the event used to drop are there" do
    msg = EDA.Event.from_raw("MESSAGE_CREATE", @payload)

    assert msg.webhook_id == "1500000000000000004"
    assert msg.application_id == "1500000000000000005"
    assert msg.flags == 1 <<< 14
    assert msg.nonce == "42"
    assert msg.position == 7
    assert msg.channel_type == :guild_text
    assert [%EDA.Message{content: "forwarded text"}] = msg.message_snapshots

    assert %EDA.Message.InteractionMetadata{user: %EDA.User{id: "11"}} =
             msg.interaction_metadata

    assert %EDA.Channel{name: "discussion"} = msg.thread
    assert [%EDA.Message.ChannelMention{name: "news"}] = msg.mention_channels
    assert %EDA.Message.Call{participants: ["11"]} = msg.call
    assert %EDA.Message.RoleSubscriptionData{tier_name: "Gold"} = msg.role_subscription_data
  end

  test "a message fetched over REST parses the same way" do
    assert EDA.Message.from_raw(@payload) == EDA.Event.from_raw("MESSAGE_CREATE", @payload)
  end

  describe "the message received can be acted on directly" do
    setup do
      bypass = Bypass.open()
      Application.put_env(:eda, :base_url, "http://localhost:#{bypass.port}")
      Application.put_env(:eda, :token, "test-token")
      on_exit(fn -> Application.delete_env(:eda, :base_url) end)
      {:ok, bypass: bypass}
    end

    test "reply/2 accepts what the consumer received", %{bypass: bypass} do
      test_pid = self()

      Bypass.expect_once(bypass, "POST", "/channels/1500000000000000002/messages", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        send(test_pid, {:body, Jason.decode!(body)})

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(%{"id" => "99", "channel_id" => "2"}))
      end)

      msg = EDA.Event.from_raw("MESSAGE_CREATE", @payload)
      assert {:ok, %EDA.Message{id: "99"}} = EDA.Message.reply(msg, "pong")

      assert_receive {:body,
                      %{
                        "content" => "pong",
                        "message_reference" => %{"message_id" => "1500000000000000001"}
                      }}
    end
  end
end
