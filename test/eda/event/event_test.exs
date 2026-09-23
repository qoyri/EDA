defmodule EDA.EventTest do
  use ExUnit.Case, async: true

  alias EDA.Event

  describe "from_raw/2" do
    test "MESSAGE_CREATE returns MessageCreate struct" do
      data = %{
        "id" => "msg1",
        "channel_id" => "ch1",
        "guild_id" => "g1",
        "author" => %{"id" => "u1", "username" => "alice"},
        "content" => "hello",
        "timestamp" => "2025-01-01T00:00:00Z",
        "tts" => false,
        "mention_everyone" => false,
        "mentions" => [],
        "mention_roles" => [],
        "attachments" => [],
        "embeds" => [],
        "pinned" => false,
        "type" => 0,
        "member" => %{"nick" => "ali", "roles" => ["r1"]}
      }

      result = Event.from_raw("MESSAGE_CREATE", data)
      assert %EDA.Message{} = result
      assert result.id == "msg1"
      assert result.content == "hello"
      assert result.channel_id == "ch1"
      assert result.guild_id == "g1"
      assert result.tts == false
      assert result.type == 0
    end

    test "MessageCreate nested maps remain string-keyed" do
      data = %{
        "id" => "msg1",
        "author" => %{"id" => "u1", "username" => "alice"},
        "member" => %{"nick" => "ali"}
      }

      result = Event.from_raw("MESSAGE_CREATE", data)
      assert result.author["username"] == "alice"
      assert result.member["nick"] == "ali"
      assert result["author"]["id"] == "u1"
    end

    test "READY returns Ready struct" do
      data = %{
        "v" => 10,
        "user" => %{"id" => "bot1", "username" => "TestBot"},
        "guilds" => [%{"id" => "g1", "unavailable" => true}],
        "session_id" => "sess1",
        "resume_gateway_url" => "wss://gateway.discord.gg",
        "shard" => [0, 1],
        "application" => %{"id" => "app1"}
      }

      result = Event.from_raw("READY", data)
      assert %Event.Ready{} = result
      assert result.v == 10
      assert result.user["username"] == "TestBot"
      assert length(result.guilds) == 1
      assert result.session_id == "sess1"
      assert result.shard == [0, 1]
    end

    test "MESSAGE_DELETE returns MessageDelete struct" do
      data = %{"id" => "msg1", "channel_id" => "ch1", "guild_id" => "g1"}
      result = Event.from_raw("MESSAGE_DELETE", data)
      assert %Event.MessageDelete{} = result
      assert result.id == "msg1"
    end

    test "VOICE_AUDIO returns VoiceAudio struct" do
      data = %{
        "guild_id" => "g1",
        "user_id" => "u1",
        "ssrc" => 12_345,
        "opus" => <<1, 2, 3>>
      }

      result = Event.from_raw("VOICE_AUDIO", data)
      assert %Event.VoiceAudio{} = result
      assert result.guild_id == "g1"
      assert result.ssrc == 12_345
      assert result.opus == <<1, 2, 3>>
    end

    test "INTERACTION_CREATE preserves nested maps" do
      data = %{
        "id" => "int1",
        "application_id" => "app1",
        "type" => 2,
        "data" => %{
          "name" => "ping",
          "type" => 1,
          "options" => []
        },
        "guild_id" => "g1",
        "channel_id" => "ch1",
        "member" => %{"user" => %{"id" => "u1", "username" => "alice"}},
        "token" => "tok1"
      }

      result = Event.from_raw("INTERACTION_CREATE", data)
      assert %Event.InteractionCreate{} = result
      assert result.data["name"] == "ping"
      assert result.member["user"]["username"] == "alice"
    end

    test "unknown event returns Raw struct" do
      data = %{"foo" => "bar", "baz" => 42}
      result = Event.from_raw("SUPER_NEW_EVENT", data)
      assert %Event.Raw{} = result
      assert result.event_type == "SUPER_NEW_EVENT"
      assert result.data == %{"foo" => "bar", "baz" => 42}
    end

    test "GUILD_CREATE extracts all fields" do
      data = %{
        "id" => "g1",
        "name" => "Test Guild",
        "owner_id" => "u1",
        "channels" => [%{"id" => "ch1"}],
        "members" => [%{"user" => %{"id" => "u1"}}],
        "roles" => [%{"id" => "r1"}],
        "member_count" => 42
      }

      result = Event.from_raw("GUILD_CREATE", data)
      assert %Event.GuildCreate{} = result
      assert result.name == "Test Guild"
      assert length(result.channels) == 1
      assert result.member_count == 42
    end

    test "VOICE_STATE_UPDATE extracts voice fields" do
      data = %{
        "guild_id" => "g1",
        "channel_id" => "vc1",
        "user_id" => "u1",
        "session_id" => "sess1",
        "self_mute" => true,
        "self_deaf" => false,
        "self_video" => true,
        "mute" => false,
        "deaf" => false
      }

      result = Event.from_raw("VOICE_STATE_UPDATE", data)
      assert %Event.VoiceStateUpdate{} = result
      assert result.self_mute == true
      assert result.self_video == true
      assert result.channel_id == "vc1"
    end
  end
end
