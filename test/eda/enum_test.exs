defmodule EDA.EnumTest do
  @moduledoc """
  Discord's integer enumerations as atoms: the atom is Discord's documented name lowercased, a
  value EDA does not know stays the integer, and every call that sends one takes the atom or the
  integer.
  """

  # NOT async — the outgoing tests use Bypass and the Application env.
  use ExUnit.Case

  doctest EDA.StageInstance

  describe "reading" do
    test "each enumeration becomes its atom" do
      assert %EDA.Message{type: :reply} = EDA.Message.from_raw(%{"type" => 19})
      assert %EDA.Webhook{type: :channel_follower} = EDA.Webhook.from_raw(%{"type" => 2})
      assert %EDA.Activity{type: :listening} = EDA.Activity.from_raw(%{"type" => 2})

      assert %EDA.PermissionOverwrite{type: :member} =
               EDA.PermissionOverwrite.from_raw(%{"type" => 1})

      assert %EDA.StageInstance{privacy_level: :guild_only} =
               EDA.StageInstance.from_raw(%{"privacy_level" => 2})

      event =
        EDA.ScheduledEvent.from_raw(%{"status" => 2, "entity_type" => 3, "privacy_level" => 2})

      assert {event.status, event.entity_type, event.privacy_level} ==
               {:active, :external, :guild_only}

      guild =
        EDA.Guild.from_raw(%{
          "verification_level" => 4,
          "default_message_notifications" => 1,
          "explicit_content_filter" => 2,
          "mfa_level" => 1,
          "nsfw_level" => 3,
          "premium_tier" => 1
        })

      assert guild.verification_level == :very_high
      assert guild.default_message_notifications == :only_mentions
      assert guild.explicit_content_filter == :all_members
      assert guild.mfa_level == :elevated
      assert guild.nsfw_level == :age_restricted
      assert guild.premium_tier == :tier_1
    end

    test "a value Discord adds before EDA knows it stays the integer" do
      assert %EDA.Message{type: 99} = EDA.Message.from_raw(%{"type" => 99})
      assert %EDA.Channel{type: 42} = EDA.Channel.from_raw(%{"type" => 42})
      assert %EDA.Guild{premium_tier: 7} = EDA.Guild.from_raw(%{"premium_tier" => 7})
    end

    test "the enumerations that already had a helper, whose helper now takes the atom too" do
      invite = EDA.Invite.from_raw(%{"code" => "x", "type" => 1, "target_type" => 2})
      assert {invite.type, invite.target_type} == {:group_dm, :embedded_application}
      assert EDA.Invite.type(invite) == :group_dm

      sub = EDA.Subscription.from_raw(%{"status" => 1})
      assert sub.status == :inactive and EDA.Subscription.status(sub) == :inactive

      user = EDA.User.from_raw(%{"id" => "1", "premium_type" => 3})
      assert user.premium_type == :nitro_basic and EDA.User.nitro?(user)

      interaction = EDA.Event.from_raw("INTERACTION_CREATE", %{"id" => "1", "type" => 5})
      assert interaction.type == :modal_submit
      assert EDA.Interaction.interaction_type(interaction) == :modal_submit

      entry = EDA.AuditLog.Entry.from_raw(%{"action_type" => 22})
      assert entry.action_type == :member_ban_add
      assert EDA.AuditLog.action_name(entry.action_type) == :member_ban_add

      rule = EDA.AutoMod.from_raw(%{"trigger_type" => 5, "event_type" => 1})
      assert {rule.trigger_type, rule.event_type} == {:mention_spam, :message_send}
    end

    test "STAGE_INSTANCE_* deliver an EDA.StageInstance" do
      for name <- ~w(STAGE_INSTANCE_CREATE STAGE_INSTANCE_UPDATE STAGE_INSTANCE_DELETE) do
        assert %EDA.StageInstance{topic: "Q&A"} =
                 EDA.Event.from_raw(name, %{"topic" => "Q&A", "privacy_level" => 2})
      end
    end
  end

  describe "sending" do
    setup do
      bypass = Bypass.open()
      Application.put_env(:eda, :base_url, "http://localhost:#{bypass.port}")
      Application.put_env(:eda, :token, "test-token")
      on_exit(fn -> Application.delete_env(:eda, :base_url) end)
      test_pid = self()

      Bypass.stub(bypass, :any, :any, fn conn ->
        {:ok, raw, conn} = Plug.Conn.read_body(conn)
        send(test_pid, {:body, conn.request_path, Jason.decode!(raw)})

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, ~s({"id":"1"}))
      end)

      :ok
    end

    test "an atom is sent as Discord's integer, an integer as is" do
      EDA.API.Guild.modify("1", %{verification_level: :high, explicit_content_filter: 2})

      assert_receive {:body, "/guilds/1",
                      %{"verification_level" => 3, "explicit_content_filter" => 2}}

      EDA.API.Channel.create("1", %{name: "voice", type: :guild_voice})
      assert_receive {:body, "/guilds/1/channels", %{"type" => 2}}

      EDA.API.Channel.edit_permissions("2", "3", type: :member, allow: "1024")
      assert_receive {:body, "/channels/2/permissions/3", %{"type" => 1}}

      EDA.API.Thread.start("2", name: "t", type: :private_thread)
      assert_receive {:body, "/channels/2/threads", %{"type" => 12}}

      EDA.API.ScheduledEvent.create("1", %{entity_type: :external, privacy_level: :guild_only})

      assert_receive {:body, "/guilds/1/scheduled-events",
                      %{"entity_type" => 3, "privacy_level" => 2}}
    end

    test "an atom Discord does not have is refused, naming the ones it does" do
      assert_raise ArgumentError,
                   ~r/unknown channel type :guild_lounge; known: :guild_text/,
                   fn ->
                     EDA.API.Channel.create("1", %{name: "x", type: :guild_lounge})
                   end
    end

    test "an AutoMod rule built with atoms and structs is sent as Discord's integers and maps" do
      EDA.API.AutoMod.create("1", %{
        name: "no slurs",
        event_type: :message_send,
        trigger_type: :keyword_preset,
        trigger_metadata: %EDA.AutoMod.TriggerMetadata{presets: [:slurs, :profanity]},
        actions: [EDA.AutoMod.Action.block_message(), %{type: :send_alert_message}]
      })

      assert_receive {:body, "/guilds/1/auto-moderation/rules", body}
      assert body["event_type"] == 1
      assert body["trigger_type"] == 4
      assert body["trigger_metadata"] == %{"presets" => [3, 1]}
      assert [%{"type" => 1}, %{"type" => 2}] = body["actions"]
    end

    test "a poll sends its layout as the integer" do
      raw = EDA.Poll.new("Lunch?") |> EDA.Poll.to_raw()
      assert raw["layout_type"] == 1
    end
  end
end
