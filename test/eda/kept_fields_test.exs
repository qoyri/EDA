defmodule EDA.KeptFieldsTest do
  @moduledoc """
  Fields Discord documents that EDA's structs used to throw away. Payloads follow Discord's
  reference for each object.
  """

  use ExUnit.Case, async: true

  test "a role keeps its flags (1 << 0: selectable in an onboarding prompt)" do
    assert %EDA.Role{flags: 1} = EDA.Role.from_raw(%{"id" => "1", "flags" => 1})
  end

  test "a reaction tells super reactions from normal ones" do
    reaction =
      EDA.Reaction.from_raw(%{
        "count" => 5,
        "count_details" => %{"burst" => 2, "normal" => 3},
        "me" => false,
        "me_burst" => true,
        "burst_colors" => ["#ff0000", "#00ff00"],
        "emoji" => %{"id" => nil, "name" => "🔥"}
      })

    assert reaction.count_details == %{burst: 2, normal: 3}
    assert reaction.me_burst
    assert reaction.burst_colors == ["#ff0000", "#00ff00"]
  end

  test "a clip attachment keeps who was in the stream and when" do
    attachment =
      EDA.Attachment.from_raw(%{
        "id" => "1",
        "filename" => "clip.mp4",
        "clip_participants" => [%{"id" => "2", "username" => "streamer"}],
        "clip_created_at" => "2026-09-23T10:00:00.000000+00:00",
        "application" => %{"id" => "3", "name" => "Some Game"}
      })

    assert [%EDA.User{username: "streamer"}] = attachment.clip_participants
    assert attachment.clip_created_at == "2026-09-23T10:00:00.000000+00:00"
    assert %{"name" => "Some Game"} = attachment.application
  end

  test "an activity keeps its status display type and its links" do
    activity =
      EDA.Activity.from_raw(%{
        "name" => "Music",
        "type" => 2,
        "status_display_type" => 1,
        "details_url" => "https://example.com/track",
        "state_url" => "https://example.com/artist"
      })

    assert activity.status_display_type == 1
    assert activity.details_url == "https://example.com/track"
    assert activity.state_url == "https://example.com/artist"
  end

  test "a channel follower webhook says what it follows" do
    webhook =
      EDA.Webhook.from_raw(%{
        "id" => "1",
        "type" => 2,
        "source_guild" => %{"id" => "4", "name" => "Announcements HQ"},
        "source_channel" => %{"id" => "5", "name" => "news"},
        "url" => "https://discord.com/api/webhooks/1/token"
      })

    assert %{"name" => "Announcements HQ"} = webhook.source_guild
    assert %{"name" => "news"} = webhook.source_channel
    assert webhook.url == "https://discord.com/api/webhooks/1/token"
  end

  test "a member fetched from the cache knows its guild" do
    guild_id = "7700000000000002001"

    EDA.Cache.Member.create(guild_id, %{"user" => %{"id" => "7700000000000002002"}, "roles" => []})

    assert {:ok, %EDA.Member{guild_id: ^guild_id}} =
             EDA.Member.fetch_member(guild_id, "7700000000000002002")
  end

  test "name styles keep their colours as integers, whatever Discord sent" do
    user =
      EDA.User.from_raw(%{
        "id" => "1",
        "display_name_styles" => %{"font_id" => 12, "effect_id" => 4, "colors" => ["16752459"]}
      })

    assert %EDA.User.DisplayNameStyles{font_id: 12, effect_id: 4, colors: [16_752_459]} =
             user.display_name_styles
  end
end
