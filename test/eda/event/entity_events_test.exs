defmodule EDA.Event.EntityEventsTest do
  @moduledoc """
  The events whose payload is an entity deliver that entity, not a wrapper around it; those that
  send the guild beside the entity put it in the entity's `guild_id`.
  """

  use ExUnit.Case, async: true

  test "role events deliver the role, with its guild" do
    for name <- ~w(GUILD_ROLE_CREATE GUILD_ROLE_UPDATE) do
      assert %EDA.Role{id: "5", name: "mod", guild_id: "1"} =
               EDA.Event.from_raw(name, %{
                 "guild_id" => "1",
                 "role" => %{"id" => "5", "name" => "mod"}
               })
    end
  end

  test "a guild's roles carry its id" do
    guild = EDA.Guild.from_raw(%{"id" => "1", "roles" => [%{"id" => "5"}]})
    assert [%EDA.Role{guild_id: "1"}] = guild.roles
  end

  test "the other entity events deliver the entity itself" do
    cases = [
      {"VOICE_STATE_UPDATE", %{"guild_id" => "1", "user_id" => "2"}, EDA.VoiceState},
      {"GUILD_SOUNDBOARD_SOUND_CREATE", %{"sound_id" => "3", "guild_id" => "1"},
       EDA.SoundboardSound},
      {"GUILD_SOUNDBOARD_SOUND_UPDATE", %{"sound_id" => "3", "guild_id" => "1"},
       EDA.SoundboardSound},
      {"AUTO_MODERATION_RULE_CREATE", %{"id" => "4", "guild_id" => "1"}, EDA.AutoMod},
      {"AUTO_MODERATION_RULE_UPDATE", %{"id" => "4", "guild_id" => "1"}, EDA.AutoMod},
      {"AUTO_MODERATION_RULE_DELETE", %{"id" => "4", "guild_id" => "1"}, EDA.AutoMod},
      {"USER_UPDATE", %{"id" => "999"}, EDA.User},
      {"ENTITLEMENT_CREATE", %{"id" => "6"}, EDA.Entitlement},
      {"ENTITLEMENT_UPDATE", %{"id" => "6"}, EDA.Entitlement},
      {"ENTITLEMENT_DELETE", %{"id" => "6"}, EDA.Entitlement},
      {"SUBSCRIPTION_CREATE", %{"id" => "7"}, EDA.Subscription},
      {"SUBSCRIPTION_UPDATE", %{"id" => "7"}, EDA.Subscription},
      {"SUBSCRIPTION_DELETE", %{"id" => "7"}, EDA.Subscription},
      {"INTEGRATION_CREATE", %{"id" => "8", "guild_id" => "1"}, EDA.Integration},
      {"INTEGRATION_UPDATE", %{"id" => "8", "guild_id" => "1"}, EDA.Integration},
      {"APPLICATION_COMMAND_PERMISSIONS_UPDATE", %{"id" => "9", "guild_id" => "1"},
       EDA.Command.Permissions}
    ]

    for {name, raw, module} <- cases do
      assert %^module{} = EDA.Event.from_raw(name, raw), name
    end
  end

  test "THREAD_MEMBER_UPDATE delivers the thread member, with its guild" do
    member =
      EDA.Event.from_raw("THREAD_MEMBER_UPDATE", %{
        "id" => "10",
        "user_id" => "2",
        "guild_id" => "1",
        "join_timestamp" => "2026-09-23T10:00:00+00:00",
        "flags" => 0
      })

    assert %EDA.Channel.ThreadMember{
             id: "10",
             guild_id: "1",
             join_timestamp: ~U[2026-09-23 10:00:00Z]
           } =
             member
  end
end
