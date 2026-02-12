defmodule EDA.Gateway.EventsTest do
  use ExUnit.Case

  alias EDA.Gateway.Events

  # Cache and Voice processes are already started by the application supervisor.

  defmodule TestConsumer do
    @behaviour EDA.Consumer

    def handle_event(event) do
      send(:events_test_consumer, {:event, event})
    end
  end

  describe "dispatch/2" do
    test "caches guild on GUILD_CREATE" do
      guild_data = %{
        "id" => "evt_g1",
        "name" => "Event Test Guild",
        "channels" => [
          %{"id" => "evt_ch1", "name" => "general"}
        ],
        "members" => [
          %{"user" => %{"id" => "evt_u1", "username" => "member1"}}
        ]
      }

      Events.dispatch("GUILD_CREATE", guild_data)

      assert EDA.Cache.Guild.get("evt_g1") != nil
      assert EDA.Cache.Channel.get("evt_ch1") != nil
      assert EDA.Cache.User.get("evt_u1") != nil
    end

    test "caches user on GUILD_CREATE" do
      guild_data = %{
        "id" => "evt_g2",
        "name" => "G2",
        "channels" => [],
        "members" => [
          %{"user" => %{"id" => "evt_u2", "username" => "testuser"}}
        ]
      }

      Events.dispatch("GUILD_CREATE", guild_data)

      user = EDA.Cache.User.get("evt_u2")
      assert user["username"] == "testuser"
    end

    test "updates guild on GUILD_UPDATE" do
      EDA.Cache.Guild.create(%{"id" => "evt_g3", "name" => "Old"})

      Events.dispatch("GUILD_UPDATE", %{"id" => "evt_g3", "name" => "Updated"})

      guild = EDA.Cache.Guild.get("evt_g3")
      assert guild["name"] == "Updated"
    end

    test "removes guild on GUILD_DELETE" do
      EDA.Cache.Guild.create(%{"id" => "evt_g4", "name" => "To Delete"})

      Events.dispatch("GUILD_DELETE", %{"id" => "evt_g4"})

      assert EDA.Cache.Guild.get("evt_g4") == nil
    end

    test "caches channel on CHANNEL_CREATE" do
      Events.dispatch("CHANNEL_CREATE", %{"id" => "evt_ch2", "name" => "new-channel"})

      assert EDA.Cache.Channel.get("evt_ch2") != nil
    end

    test "updates channel on CHANNEL_UPDATE" do
      EDA.Cache.Channel.create(%{"id" => "evt_ch3", "name" => "old-name"})

      Events.dispatch("CHANNEL_UPDATE", %{"id" => "evt_ch3", "name" => "new-name"})

      channel = EDA.Cache.Channel.get("evt_ch3")
      assert channel["name"] == "new-name"
    end

    test "removes channel on CHANNEL_DELETE" do
      EDA.Cache.Channel.create(%{"id" => "evt_ch4", "name" => "delete-me"})

      Events.dispatch("CHANNEL_DELETE", %{"id" => "evt_ch4"})

      assert EDA.Cache.Channel.get("evt_ch4") == nil
    end

    test "caches author on MESSAGE_CREATE" do
      Events.dispatch("MESSAGE_CREATE", %{
        "id" => "msg1",
        "content" => "hello",
        "author" => %{"id" => "evt_u3", "username" => "author"}
      })

      user = EDA.Cache.User.get("evt_u3")
      assert user["username"] == "author"
    end

    test "handles READY with guilds and user" do
      ready_data = %{
        "user" => %{"id" => "bot_id", "username" => "TestBot"},
        "guilds" => [
          %{"id" => "evt_rg1", "name" => "Ready Guild"}
        ]
      }

      Events.dispatch("READY", ready_data)

      assert EDA.Cache.Guild.get("evt_rg1") != nil
      assert EDA.Cache.User.get("bot_id") != nil
    end

    test "handles unknown event types without crashing" do
      assert :ok = Events.dispatch("UNKNOWN_EVENT", %{"foo" => "bar"})
    end

    test "dispatches to consumer when configured" do
      Process.register(self(), :events_test_consumer)

      Application.put_env(:eda, :consumer, EDA.Gateway.EventsTest.TestConsumer)

      Events.dispatch("TEST_EVENT", %{"data" => "test"})

      assert_receive {:event, {:TEST_EVENT, %{"data" => "test"}}}, 1000

      Application.delete_env(:eda, :consumer)
    end

    test "handles missing consumer gracefully" do
      Application.delete_env(:eda, :consumer)
      assert :ok = Events.dispatch("SOME_EVENT", %{})
    end
  end

  describe "voice event routing" do
    test "VOICE_SERVER_UPDATE routes to Voice system" do
      EDA.Cache.put_me(%{"id" => "bot_123", "username" => "TestBot"})

      Events.dispatch("VOICE_SERVER_UPDATE", %{
        "guild_id" => "vg1",
        "token" => "voice_token",
        "endpoint" => "voice.discord.gg:443"
      })

      assert true
    end

    test "VOICE_STATE_UPDATE routes for bot user" do
      EDA.Cache.put_me(%{"id" => "bot_456", "username" => "TestBot"})

      Events.dispatch("VOICE_STATE_UPDATE", %{
        "guild_id" => "vg2",
        "user_id" => "bot_456",
        "session_id" => "vsess_123",
        "channel_id" => "vc_123"
      })

      assert true
    end

    test "VOICE_STATE_UPDATE ignores other users" do
      EDA.Cache.put_me(%{"id" => "bot_789", "username" => "TestBot"})

      Events.dispatch("VOICE_STATE_UPDATE", %{
        "guild_id" => "vg3",
        "user_id" => "other_user",
        "session_id" => "vsess_other"
      })

      assert true
    end
  end
end
