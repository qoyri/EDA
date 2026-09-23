defmodule EDA.Message.NestedTest do
  @moduledoc """
  The objects a message nests are structs: its reference, stickers, interaction, call, activity,
  role subscription, theme, crossposted channel mentions, application and resolved data.
  """

  use ExUnit.Case, async: true

  alias EDA.Message

  doctest EDA.Resolved
  doctest EDA.Sticker.Item

  test "a forwarded message: its reference and the message it forwards" do
    msg =
      Message.from_raw(%{
        "id" => "3",
        "message_reference" => %{"type" => 1, "message_id" => "1", "channel_id" => "2"},
        "message_snapshots" => [%{"message" => %{"content" => "hi", "type" => 0, "flags" => 0}}]
      })

    assert %Message.Reference{type: :forward, message_id: "1", channel_id: "2"} =
             msg.message_reference

    assert [%Message{content: "hi", type: :default}] = msg.message_snapshots
  end

  test "a reply's reference defaults to :default, and is sent as Discord takes it" do
    reference = Message.Reference.from_raw(%{"message_id" => "1", "fail_if_not_exists" => false})
    assert reference.type == :default

    assert reference |> Jason.encode!() |> Jason.decode!() ==
             %{"type" => 0, "message_id" => "1", "fail_if_not_exists" => false}
  end

  test "stickers, call, activity, subscription, theme and application" do
    msg =
      Message.from_raw(%{
        "sticker_items" => [%{"id" => "5", "name" => "wave", "format_type" => 3}],
        "call" => %{
          "participants" => ["1", "2"],
          "ended_timestamp" => "2026-09-23T10:00:00+00:00"
        },
        "activity" => %{"type" => 3, "party_id" => "spotify:1"},
        "role_subscription_data" => %{
          "role_subscription_listing_id" => "9",
          "tier_name" => "Gold",
          "total_months_subscribed" => 4,
          "is_renewal" => true
        },
        "shared_client_theme" => %{
          "colors" => ["5865F2", "EB459E"],
          "gradient_angle" => 90,
          "base_mix" => 60,
          "base_theme" => 1
        },
        "application" => %{"id" => "7", "name" => "Game"},
        "channel_type" => 11
      })

    assert [%EDA.Sticker.Item{id: "5", format_type: :lottie}] = msg.sticker_items

    assert %Message.Call{participants: ["1", "2"], ended_timestamp: ~U[2026-09-23 10:00:00Z]} =
             msg.call

    assert %Message.Activity{type: :listen, party_id: "spotify:1"} = msg.activity

    assert %Message.RoleSubscriptionData{total_months_subscribed: 4, is_renewal: true} =
             msg.role_subscription_data

    assert %Message.SharedClientTheme{gradient_angle: 90, colors: ["5865F2", "EB459E"]} =
             msg.shared_client_theme

    assert %EDA.App{id: "7", name: "Game"} = msg.application
    assert msg.channel_type == :public_thread
  end

  test "the interaction a message answers, and the one that opened its modal" do
    metadata =
      Message.from_raw(%{
        "interaction_metadata" => %{
          "id" => "10",
          "type" => 5,
          "user" => %{"id" => "1", "username" => "ann"},
          "authorizing_integration_owners" => %{"0" => "100", "1" => "1"},
          "triggering_interaction_metadata" => %{"id" => "9", "type" => 3},
          "interacted_message_id" => "8"
        }
      }).interaction_metadata

    assert %Message.InteractionMetadata{
             type: :modal_submit,
             user: %EDA.User{username: "ann"},
             authorizing_integration_owners: %{guild_install: "100", user_install: "1"},
             triggering_interaction_metadata: %Message.InteractionMetadata{type: :component}
           } = metadata
  end

  test "resolved data, each entry its struct, members with their user" do
    resolved =
      Message.from_raw(%{
        "resolved" => %{
          "users" => %{"1" => %{"id" => "1", "username" => "ann"}},
          "members" => %{"1" => %{"nick" => "Annie", "roles" => []}},
          "roles" => %{"2" => %{"id" => "2", "name" => "mod"}},
          "channels" => %{"3" => %{"id" => "3", "type" => 0, "name" => "general"}},
          "attachments" => %{"4" => %{"id" => "4", "filename" => "a.png"}}
        }
      }).resolved

    assert %EDA.Member{nick: "Annie", user: %EDA.User{username: "ann"}} = resolved.members["1"]
    assert %EDA.Role{name: "mod"} = resolved.roles["2"]
    assert %EDA.Channel{type: :guild_text} = resolved.channels["3"]
    assert %EDA.Attachment{filename: "a.png"} = resolved.attachments["4"]
    assert resolved.messages == %{}
  end

  test "a crossposted message's channel mentions" do
    msg =
      Message.from_raw(%{
        "mention_channels" => [%{"id" => "1", "guild_id" => "2", "type" => 5, "name" => "news"}]
      })

    assert [%Message.ChannelMention{type: :guild_announcement, name: "news"}] =
             msg.mention_channels
  end

  test "a guild message's mentioned users carry their partial member, with the guild" do
    msg =
      Message.from_raw(%{
        "guild_id" => "9",
        "mentions" => [
          %{"id" => "1", "username" => "ann", "member" => %{"nick" => "Annie", "roles" => ["5"]}},
          %{"id" => "2", "username" => "bob"}
        ]
      })

    assert [%EDA.User{username: "ann", member: member}, %EDA.User{member: nil}] = msg.mentions
    assert %EDA.Member{nick: "Annie", roles: ["5"], guild_id: "9"} = member
  end
end
