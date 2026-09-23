defmodule EDA.GuildNestedTest do
  @moduledoc """
  What a guild nests — its welcome screen, safety actions and the lists `GUILD_CREATE` carries —
  and a forum's default reaction are structs.
  """

  use ExUnit.Case, async: true

  test "a guild's welcome screen and incidents" do
    guild =
      EDA.Guild.from_raw(%{
        "id" => "1",
        "welcome_screen" => %{
          "description" => "Hi!",
          "welcome_channels" => [
            %{
              "channel_id" => "2",
              "description" => "Rules",
              "emoji_id" => nil,
              "emoji_name" => "📜"
            }
          ]
        },
        "incidents_data" => %{
          "invites_disabled_until" => "2026-09-24T10:00:00+00:00",
          "dms_disabled_until" => nil,
          "raid_detected_at" => "2026-09-23T09:00:00.000000+00:00"
        }
      })

    assert %EDA.Guild.WelcomeScreen{
             description: "Hi!",
             welcome_channels: [
               %EDA.Guild.WelcomeScreen.Channel{channel_id: "2", emoji_name: "📜"}
             ]
           } = guild.welcome_screen

    assert guild.incidents_data.invites_disabled_until == ~U[2026-09-24 10:00:00Z]
    assert guild.incidents_data.raid_detected_at == ~U[2026-09-23 09:00:00.000000Z]
    assert guild.incidents_data.dms_disabled_until == nil

    assert guild.welcome_screen |> Jason.encode!() |> Jason.decode!() == %{
             "description" => "Hi!",
             "welcome_channels" => [
               %{
                 "channel_id" => "2",
                 "description" => "Rules",
                 "emoji_id" => nil,
                 "emoji_name" => "📜"
               }
             ]
           }
  end

  test "GUILD_CREATE's presences, stage instances and scheduled events" do
    guild =
      EDA.Event.from_raw("GUILD_CREATE", %{
        "id" => "1",
        "presences" => [%{"user" => %{"id" => "3"}, "status" => "idle"}],
        "stage_instances" => [%{"id" => "4", "topic" => "Q&A", "privacy_level" => 2}],
        "guild_scheduled_events" => [%{"id" => "5", "name" => "Launch", "status" => 2}]
      })

    assert [%EDA.Event.PresenceUpdate{guild_id: "1", status: :idle}] = guild.presences
    assert [%EDA.StageInstance{topic: "Q&A", privacy_level: :guild_only}] = guild.stage_instances
    assert [%EDA.ScheduledEvent{name: "Launch", status: :active}] = guild.guild_scheduled_events
  end

  test "a members chunk's members and presences carry the guild" do
    chunk =
      EDA.Event.from_raw("GUILD_MEMBERS_CHUNK", %{
        "guild_id" => "1",
        "members" => [%{"user" => %{"id" => "3"}, "roles" => []}],
        "presences" => [%{"user" => %{"id" => "3"}, "status" => "online"}]
      })

    assert [%EDA.Member{guild_id: "1"}] = chunk.members
    assert [%EDA.Event.PresenceUpdate{guild_id: "1", status: :online}] = chunk.presences
  end

  test "a forum's default reaction, sent back as Discord takes it" do
    channel =
      EDA.Channel.from_raw(%{
        "id" => "1",
        "type" => 15,
        "default_reaction_emoji" => %{"emoji_id" => nil, "emoji_name" => "👍"}
      })

    reaction = channel.forum.default_reaction_emoji
    assert reaction == %EDA.Channel.DefaultReaction{emoji_name: "👍"}
    assert Jason.encode!(reaction) |> Jason.decode!() == %{"emoji_id" => nil, "emoji_name" => "👍"}
  end
end
