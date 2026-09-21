defmodule EDA.GatewayAuditTest do
  @moduledoc """
  What the 2026-09-21 audit of Discord's reference found missing on the gateway side: events that
  fell through to `EDA.Event.Raw`, `USER_UPDATE` leaving the cached bot user stale, opcode 43,
  and audit log action types. Payloads follow the gateway events reference.
  """

  # NOT async — USER_UPDATE writes the cached bot user, which is global.
  use ExUnit.Case

  doctest EDA.Entitlement
  doctest EDA.Command.Permissions

  describe "every event the reference documents is typed" do
    test "entitlements" do
      raw = %{
        "id" => "1",
        "sku_id" => "2",
        "application_id" => "3",
        "user_id" => "4",
        "type" => 8,
        "deleted" => false,
        "starts_at" => "2026-09-01T00:00:00+00:00",
        "ends_at" => "2026-10-01T00:00:00+00:00"
      }

      for type <- ~w(ENTITLEMENT_CREATE ENTITLEMENT_UPDATE ENTITLEMENT_DELETE) do
        assert %{entitlement: %EDA.Entitlement{id: "1", type: :application_subscription}} =
                 EDA.Event.from_raw(type, raw)
      end

      entitlement = EDA.Entitlement.from_raw(raw)
      assert EDA.Entitlement.active?(entitlement, ~U[2026-09-15 00:00:00Z])
      refute EDA.Entitlement.active?(entitlement, ~U[2026-10-02 00:00:00Z])
      refute EDA.Entitlement.active?(entitlement, ~U[2026-08-31 00:00:00Z])
      refute EDA.Entitlement.active?(%{entitlement | deleted: true}, ~U[2026-09-15 00:00:00Z])
    end

    test "subscriptions reuse EDA.Subscription" do
      for type <- ~w(SUBSCRIPTION_CREATE SUBSCRIPTION_UPDATE SUBSCRIPTION_DELETE) do
        assert %{subscription: %EDA.Subscription{id: "9"}} =
                 EDA.Event.from_raw(type, %{"id" => "9", "user_id" => "4", "status" => 0})
      end
    end

    test "integrations" do
      raw = %{
        "id" => "5",
        "guild_id" => "6",
        "name" => "Some Bot",
        "type" => "discord",
        "enabled" => true,
        "expire_behavior" => 1,
        "account" => %{"id" => "7", "name" => "Some Bot"},
        "application" => %{"id" => "7", "name" => "Some Bot"},
        "scopes" => ["bot"]
      }

      assert %EDA.Event.IntegrationCreate{guild_id: "6", integration: integration} =
               EDA.Event.from_raw("INTEGRATION_CREATE", raw)

      assert %EDA.Integration{expire_behavior: :kick, scopes: ["bot"]} = integration
      assert EDA.Integration.application?(integration)

      assert %EDA.Event.IntegrationUpdate{integration: %EDA.Integration{id: "5"}} =
               EDA.Event.from_raw("INTEGRATION_UPDATE", raw)

      assert %EDA.Event.IntegrationDelete{id: "5", guild_id: "6", application_id: "7"} =
               EDA.Event.from_raw("INTEGRATION_DELETE", %{
                 "id" => "5",
                 "guild_id" => "6",
                 "application_id" => "7"
               })

      assert %EDA.Event.GuildIntegrationsUpdate{guild_id: "6"} =
               EDA.Event.from_raw("GUILD_INTEGRATIONS_UPDATE", %{"guild_id" => "6"})
    end

    test "command permissions, with the @everyone and all-channels constants" do
      event =
        EDA.Event.from_raw("APPLICATION_COMMAND_PERMISSIONS_UPDATE", %{
          "id" => "3",
          "application_id" => "3",
          "guild_id" => "10",
          "permissions" => [
            %{"id" => "10", "type" => 1, "permission" => false},
            %{"id" => "9", "type" => 3, "permission" => true},
            %{"id" => "42", "type" => 2, "permission" => true}
          ]
        })

      assert %EDA.Event.ApplicationCommandPermissionsUpdate{permissions: perms} = event
      assert EDA.Command.Permissions.app_wide?(perms)
      [everyone, channels, user] = perms.permissions
      assert EDA.Command.Permissions.everyone?(everyone, "10")
      assert EDA.Command.Permissions.all_channels?(channels, "10")
      assert user.type == :user
    end

    test "channel info and voice start times, as DateTimes" do
      assert %EDA.Event.ChannelInfo{guild_id: "1", channels: [a, b]} =
               EDA.Event.from_raw("CHANNEL_INFO", %{
                 "guild_id" => "1",
                 "channels" => [
                   %{"id" => "2", "status" => "Raid night", "voice_start_time" => 1_790_000_000},
                   %{"id" => "3", "status" => nil, "voice_start_time" => nil}
                 ]
               })

      assert a.status == "Raid night"
      assert a.voice_start_time == DateTime.from_unix!(1_790_000_000)
      assert b.voice_start_time == nil

      # The live gateway sends the time as a string, though the reference says integer.
      assert %EDA.Event.VoiceChannelStartTimeUpdate{voice_start_time: started} =
               EDA.Event.from_raw("VOICE_CHANNEL_START_TIME_UPDATE", %{
                 "id" => "1241165937281863731",
                 "guild_id" => "1174108031374602240",
                 "voice_start_time" => "1790002356"
               })

      assert started == DateTime.from_unix!(1_790_002_356)

      assert %EDA.Event.VoiceChannelStartTimeUpdate{channel_id: "2", voice_start_time: nil} =
               EDA.Event.from_raw("VOICE_CHANNEL_START_TIME_UPDATE", %{
                 "id" => "2",
                 "guild_id" => "1",
                 "voice_start_time" => nil
               })
    end
  end

  describe "USER_UPDATE" do
    setup do
      previous = :persistent_term.get(:eda_current_user_raw, nil)

      EDA.Cache.put_me(%{
        "id" => "999",
        "username" => "old name",
        "bot" => true,
        "verified" => true
      })

      on_exit(fn ->
        if previous,
          do: EDA.Cache.put_me(previous),
          else:
            :persistent_term.erase(:eda_current_user) &&
              :persistent_term.erase(:eda_current_user_raw)
      end)
    end

    test "updates the cached bot user, keeping fields the event does not carry" do
      EDA.Gateway.Events.dispatch("USER_UPDATE", %{"id" => "999", "username" => "new name"})

      assert EDA.Cache.me().username == "new name"
      assert EDA.Cache.me_raw()["verified"] == true
    end

    test "is typed" do
      assert %EDA.Event.UserUpdate{user: %EDA.User{id: "999"}} =
               EDA.Event.from_raw("USER_UPDATE", %{"id" => "999", "username" => "x"})
    end

    test "another user's payload does not replace the bot user" do
      EDA.Gateway.Events.dispatch("USER_UPDATE", %{
        "id" => "7700000000000000123",
        "username" => "someone"
      })

      assert EDA.Cache.me().username == "old name"
    end
  end

  describe "opcode 43" do
    test "a request is encoded as Request Channel Info" do
      state = %EDA.Gateway.Connection{encoding: EDA.Gateway.Encoding.JSON}

      assert {:reply, {:text, json}, ^state} =
               EDA.Gateway.Connection.handle_cast(
                 {:request_channel_info, "1", ["status", "voice_start_time"]},
                 state
               )

      assert Jason.decode!(json) == %{
               "op" => 43,
               "d" => %{"guild_id" => "1", "fields" => ["status", "voice_start_time"]}
             }
    end

    test "EDA.Channel.request_info/2 refuses a field Discord does not offer" do
      assert_raise ArgumentError, ~r/:status, :voice_start_time/, fn ->
        EDA.Channel.request_info("1", [:name])
      end
    end
  end

  describe "audit log action types" do
    test "the fifteen the reference added are named" do
      for {value, name} <- [
            {130, :soundboard_sound_create},
            {146, :auto_moderation_quarantine_user},
            {151, :creator_monetization_terms_accepted},
            {163, :onboarding_prompt_create},
            {167, :onboarding_update},
            {191, :home_settings_update},
            {193, :voice_channel_status_delete}
          ] do
        assert EDA.AuditLog.action_name(value) == name
        assert EDA.AuditLog.action_type(name) == value
      end
    end
  end
end
