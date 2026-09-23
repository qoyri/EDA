defmodule EDA.SoundboardTest do
  @moduledoc """
  Soundboard sounds: the REST routes, the sound upload format, the struct, the gateway events
  and the opcode that requests sounds over the gateway.

  Shapes and limits follow Discord's soundboard reference: the guild list comes wrapped in
  `items`, a sound is uploaded as an MP3 or Ogg data URI of at most 512 KiB, default sounds
  carry small integer ids, and playing one needs the bot in the channel.
  """

  # NOT async — Bypass and the Application env are global.
  use ExUnit.Case

  alias EDA.API.Soundboard
  alias EDA.SoundboardSound

  doctest EDA.SoundData
  doctest EDA.SoundboardSound

  @mp3 "ID3" <> <<4, 0, 0, 0, 0, 0, 0>> <> :binary.copy(<<0xFF, 0xFB, 0x90, 0x00>>, 8)
  @ogg "OggS" <> <<0, 2>> <> :binary.copy(<<0>>, 20)

  setup do
    bypass = Bypass.open()
    Application.put_env(:eda, :base_url, "http://localhost:#{bypass.port}")
    Application.put_env(:eda, :token, "test-token")
    on_exit(fn -> Application.delete_env(:eda, :base_url) end)
    {:ok, bypass: bypass}
  end

  defp capture(bypass, method, path, status, response \\ %{}) do
    test_pid = self()

    Bypass.expect_once(bypass, method, path, fn conn ->
      {:ok, raw, conn} = Plug.Conn.read_body(conn)
      body = if raw == "", do: nil, else: Jason.decode!(raw)
      send(test_pid, {:captured, body, Plug.Conn.get_req_header(conn, "x-audit-log-reason")})

      if status == 204 do
        Plug.Conn.resp(conn, 204, "")
      else
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(status, Jason.encode!(response))
      end
    end)
  end

  describe "EDA.SoundData" do
    test "encodes MP3 and Ogg as data URIs, identified by their header" do
      assert "data:audio/mpeg;base64," <> _ = EDA.SoundData.from_binary(@mp3)
      assert "data:audio/ogg;base64," <> _ = EDA.SoundData.from_binary(@ogg)
    end

    test "an untagged MP3 is recognised by its frame sync" do
      assert {:ok, :mp3} = EDA.SoundData.type(<<0xFF, 0xF3, 0x44, 0xC4>>)
    end

    test "refuses another format, saying the header decides" do
      assert_raise ArgumentError, ~r/MP3 or Ogg.*header/, fn ->
        EDA.SoundData.from_binary("RIFF" <> <<0, 0, 0, 0>> <> "WAVEfmt ")
      end
    end

    test "refuses more than 512 KiB" do
      too_big = "ID3" <> :binary.copy(<<0>>, 512 * 1024)

      assert_raise ArgumentError, ~r/at most 512 KiB/, fn ->
        EDA.SoundData.from_binary(too_big)
      end
    end

    test "reads a path", %{bypass: _} do
      path = Path.join(System.tmp_dir!(), "eda_sound_#{System.unique_integer([:positive])}.ogg")
      File.write!(path, @ogg)
      on_exit(fn -> File.rm(path) end)

      assert EDA.SoundData.coerce(path) == EDA.SoundData.from_binary(@ogg)
    end

    test "a missing path says so" do
      assert_raise ArgumentError, ~r/does not exist/, fn ->
        EDA.SoundData.coerce("/nonexistent/airhorn.mp3")
      end
    end
  end

  describe "EDA.API.Soundboard" do
    test "list/1 unwraps Discord's items envelope", %{bypass: bypass} do
      capture(bypass, "GET", "/guilds/1/soundboard-sounds", 200, %{
        "items" => [%{"sound_id" => "9", "name" => "yay"}]
      })

      assert {:ok, [%{"sound_id" => "9"}]} = Soundboard.list("1")
    end

    test "default_sounds/0 hits the global route", %{bypass: bypass} do
      capture(bypass, "GET", "/soundboard-default-sounds", 200, [%{"sound_id" => "1"}])
      assert {:ok, [%{"sound_id" => "1"}]} = Soundboard.default_sounds()
    end

    test "create/2 sends the sound as a data URI, with the reason as a header",
         %{bypass: bypass} do
      capture(bypass, "POST", "/guilds/1/soundboard-sounds", 200, %{"sound_id" => "5"})

      assert {:ok, %{"sound_id" => "5"}} =
               Soundboard.create("1",
                 name: "airhorn",
                 sound: @mp3,
                 volume: 0.5,
                 emoji_name: "📯",
                 reason: "party"
               )

      assert_receive {:captured, body, [reason]}
      assert "data:audio/mpeg;base64," <> _ = body["sound"]
      assert body["name"] == "airhorn"
      assert body["volume"] == 0.5
      assert body["emoji_name"] == "📯"
      refute Map.has_key?(body, "reason")
      assert reason == "party"
    end

    test "create/2 checks what it can before sending" do
      assert_raise ArgumentError, ~r/requires :sound/, fn ->
        Soundboard.create("1", name: "ok")
      end

      assert_raise ArgumentError, ~r/2–32 characters/, fn ->
        Soundboard.create("1", name: "a", sound: @mp3)
      end

      assert_raise ArgumentError, ~r/volume is from 0 to 1/, fn ->
        Soundboard.create("1", name: "ok", sound: @mp3, volume: 2)
      end

      assert_raise ArgumentError, ~r/unknown option \[:emoji\]/, fn ->
        Soundboard.create("1", name: "ok", sound: @mp3, emoji: "📯")
      end
    end

    test "modify/3 sends only what changes, and cannot replace the audio", %{bypass: bypass} do
      capture(bypass, "PATCH", "/guilds/1/soundboard-sounds/5", 200, %{"sound_id" => "5"})
      assert {:ok, _} = Soundboard.modify("1", "5", volume: nil, name: "horn")
      assert_receive {:captured, %{"volume" => nil, "name" => "horn"}, []}

      assert_raise ArgumentError, ~r/unknown option \[:sound\]/, fn ->
        Soundboard.modify("1", "5", sound: @mp3)
      end
    end

    test "delete/3 answers :ok and carries the reason", %{bypass: bypass} do
      capture(bypass, "DELETE", "/guilds/1/soundboard-sounds/5", 204)
      assert :ok = Soundboard.delete("1", "5", reason: "old")
      assert_receive {:captured, nil, ["old"]}
    end

    test "send_sound/3 posts the sound id, and the source guild when given", %{bypass: bypass} do
      capture(bypass, "POST", "/channels/7/send-soundboard-sound", 204)
      assert :ok = Soundboard.send_sound("7", 1)
      assert_receive {:captured, %{"sound_id" => "1"}, _}

      capture(bypass, "POST", "/channels/7/send-soundboard-sound", 204)
      assert :ok = Soundboard.send_sound("7", "5", source_guild_id: 2)
      assert_receive {:captured, %{"sound_id" => "5", "source_guild_id" => "2"}, _}
    end
  end

  describe "EDA.SoundboardSound" do
    test "from_raw/1 keeps the fields, the creator as a struct, and ids as strings" do
      sound =
        SoundboardSound.from_raw(%{
          "sound_id" => 3,
          "name" => "Yay",
          "volume" => 1,
          "emoji_id" => "989",
          "emoji_name" => nil,
          "guild_id" => "613",
          "available" => false,
          "user" => %{"id" => "42", "username" => "ada"}
        })

      assert %SoundboardSound{sound_id: "3", guild_id: "613", available: false} = sound
      assert %EDA.User{id: "42"} = sound.user
      refute SoundboardSound.default?(sound)
      assert sound[:name] == "Yay"
    end

    test "list/1 returns structs", %{bypass: bypass} do
      capture(bypass, "GET", "/guilds/1/soundboard-sounds", 200, %{
        "items" => [%{"sound_id" => "9", "name" => "yay", "guild_id" => "1"}]
      })

      assert {:ok, [%SoundboardSound{sound_id: "9"}]} = SoundboardSound.list("1")
    end

    test "play/3 supplies the source guild of a guild sound", %{bypass: bypass} do
      capture(bypass, "POST", "/channels/7/send-soundboard-sound", 204)
      sound = %SoundboardSound{sound_id: "5", guild_id: "2"}
      assert :ok = SoundboardSound.play(sound, "7")
      assert_receive {:captured, %{"sound_id" => "5", "source_guild_id" => "2"}, _}
    end

    test "play/3 sends no source guild for a default sound", %{bypass: bypass} do
      capture(bypass, "POST", "/channels/7/send-soundboard-sound", 204)
      assert :ok = SoundboardSound.play(%SoundboardSound{sound_id: "1"}, "7")
      assert_receive {:captured, body, _}
      assert body == %{"sound_id" => "1"}
    end
  end

  describe "gateway events" do
    test "every soundboard event is registered, not left to EDA.Event.Raw" do
      sound = %{"sound_id" => "5", "name" => "yay", "guild_id" => "1"}

      assert %SoundboardSound{guild_id: "1", sound_id: "5"} =
               EDA.Event.from_raw("GUILD_SOUNDBOARD_SOUND_CREATE", sound)

      assert %SoundboardSound{name: "yay"} =
               EDA.Event.from_raw("GUILD_SOUNDBOARD_SOUND_UPDATE", sound)

      assert %EDA.Event.GuildSoundboardSoundDelete{guild_id: "1", sound_id: "5"} =
               EDA.Event.from_raw("GUILD_SOUNDBOARD_SOUND_DELETE", %{
                 "guild_id" => "1",
                 "sound_id" => "5"
               })

      list = %{"guild_id" => "1", "soundboard_sounds" => [sound]}

      assert %EDA.Event.GuildSoundboardSoundsUpdate{soundboard_sounds: [%SoundboardSound{}]} =
               EDA.Event.from_raw("GUILD_SOUNDBOARD_SOUNDS_UPDATE", list)

      assert %EDA.Event.SoundboardSounds{guild_id: "1", soundboard_sounds: [%SoundboardSound{}]} =
               EDA.Event.from_raw("SOUNDBOARD_SOUNDS", list)
    end

    test "VOICE_CHANNEL_EFFECT_SEND: a soundboard effect, with its default sound's integer id" do
      event =
        EDA.Event.from_raw("VOICE_CHANNEL_EFFECT_SEND", %{
          "channel_id" => "7",
          "guild_id" => "1",
          "user_id" => "42",
          "emoji" => %{"id" => nil, "name" => "🦆"},
          "animation_type" => 1,
          "animation_id" => 3,
          "sound_id" => 1,
          "sound_volume" => 0.8
        })

      assert %EDA.Event.VoiceChannelEffectSend{
               sound_id: "1",
               sound_volume: 0.8,
               animation_type: :basic,
               emoji: %EDA.Emoji{name: "🦆"}
             } = event

      assert EDA.Event.VoiceChannelEffectSend.soundboard?(event)
    end

    test "VOICE_CHANNEL_EFFECT_SEND: an emoji reaction has no sound" do
      event =
        EDA.Event.from_raw("VOICE_CHANNEL_EFFECT_SEND", %{
          "channel_id" => "7",
          "user_id" => "42",
          "emoji" => %{"name" => "🔥"},
          "animation_type" => 0
        })

      assert event.animation_type == :premium
      refute EDA.Event.VoiceChannelEffectSend.soundboard?(event)
    end
  end

  describe "opcode 31" do
    test "a request is encoded as Request Soundboard Sounds" do
      state = %EDA.Gateway.Connection{encoding: EDA.Gateway.Encoding.JSON}

      assert {:reply, frame, ^state} =
               EDA.Gateway.Connection.handle_cast({:request_soundboard_sounds, ["1", "2"]}, state)

      {:text, json} = frame
      assert Jason.decode!(json) == %{"op" => 31, "d" => %{"guild_ids" => ["1", "2"]}}
    end
  end
end
