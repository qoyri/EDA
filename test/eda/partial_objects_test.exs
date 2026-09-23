defmodule EDA.PartialObjectsTest do
  @moduledoc """
  The partial guilds, channels, applications and events other objects nest are their structs.
  """

  use ExUnit.Case, async: true

  test "an invite's guild, channel, target application and event" do
    invite =
      EDA.Invite.from_raw(%{
        "code" => "abc",
        "guild" => %{"id" => "1", "name" => "EDA", "features" => ["COMMUNITY"]},
        "channel" => %{"id" => "2", "name" => "welcome", "type" => 0},
        "target_application" => %{"id" => "3", "name" => "Poker"},
        "guild_scheduled_event" => %{"id" => "4", "name" => "Launch", "status" => 1}
      })

    assert %EDA.Guild{name: "EDA", features: ["COMMUNITY"]} = invite.guild
    assert %EDA.Channel{name: "welcome", type: :guild_text} = invite.channel
    assert {invite.guild_id, invite.channel_id} == {"1", "2"}
    assert %EDA.App{name: "Poker"} = invite.target_application
    assert %EDA.ScheduledEvent{name: "Launch", status: :scheduled} = invite.guild_scheduled_event
    assert invite.guild["name"] == "EDA"
  end

  test "an integration's account and application" do
    integration =
      EDA.Integration.from_raw(%{
        "id" => "1",
        "type" => "discord",
        "account" => %{"id" => "5", "name" => "Bot"},
        "application" => %{"id" => "5", "name" => "Bot", "bot" => %{"id" => "5", "bot" => true}}
      })

    assert integration.account == %EDA.Integration.Account{id: "5", name: "Bot"}
    assert %EDA.App{bot: %EDA.User{bot: true}} = integration.application
  end

  test "an application's team, with its members" do
    app =
      EDA.App.from_raw(%{
        "id" => "1",
        "team" => %{
          "id" => "2",
          "name" => "Devs",
          "owner_user_id" => "3",
          "members" => [
            %{
              "team_id" => "2",
              "role" => "developer",
              "membership_state" => 2,
              "user" => %{"id" => "4", "username" => "ann"}
            }
          ]
        },
        "guild" => %{"id" => "9", "name" => "Support"}
      })

    assert %EDA.Team{name: "Devs", members: [member]} = app.team
    assert %EDA.Team.Member{role: :developer, membership_state: :accepted} = member
    assert member.user.username == "ann"
    assert %EDA.Guild{name: "Support"} = app.guild
  end

  test "READY lists the guilds as unavailable EDA.Guild structs and the application" do
    ready =
      EDA.Event.from_raw("READY", %{
        "guilds" => [%{"id" => "1", "unavailable" => true}],
        "application" => %{"id" => "2", "flags" => 8_388_608}
      })

    assert [%EDA.Guild{id: "1", unavailable: true}] = ready.guilds
    assert %EDA.App{id: "2"} = ready.application
  end
end
