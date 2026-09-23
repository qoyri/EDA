defmodule EDA.GuildCompleteTest do
  @moduledoc """
  `EDA.Guild` keeps every field of the guild object, and the guild cache holds that object alone.

  The struct used to keep 12 fields — no `features`, no boost level, no system channel. And the
  cache stored the whole `GUILD_CREATE`, members included: `EDA.Guild.fetch/1` returned channels,
  members and roles frozen at the moment the bot joined, and every member was held twice, the
  second copy outside the member cache's `max_size`.
  """

  # NOT async — the caches are global.
  use ExUnit.Case

  @guild_id "7700000000000001001"

  @guild_create %{
    "id" => @guild_id,
    "name" => "Test",
    "owner_id" => "1",
    "icon" => "a_icon",
    "banner" => "banner_hash",
    "splash" => "splash_hash",
    "description" => "A guild",
    "features" => ["COMMUNITY", "ANIMATED_ICON"],
    "premium_tier" => 2,
    "premium_subscription_count" => 9,
    "vanity_url_code" => "test",
    "preferred_locale" => "fr",
    "verification_level" => 2,
    "mfa_level" => 1,
    "system_channel_id" => "7700000000000001010",
    "rules_channel_id" => "7700000000000001011",
    "afk_timeout" => 300,
    "max_members" => 500_000,
    "incidents_data" => %{"invites_disabled_until" => nil},
    "emojis" => [%{"id" => "7700000000000001050", "name" => "blob"}],
    "stickers" => [],
    "roles" => [%{"id" => @guild_id, "name" => "@everyone", "position" => 0}],
    "joined_at" => "2026-09-23T10:00:00.000000+00:00",
    "large" => false,
    "member_count" => 1,
    "channels" => [%{"id" => "7700000000000001010", "type" => 0, "name" => "general"}],
    "threads" => [
      %{
        "id" => "7700000000000001020",
        "type" => 11,
        "parent_id" => "7700000000000001010",
        "thread_metadata" => %{"archived" => false}
      }
    ],
    "members" => [%{"user" => %{"id" => "1", "username" => "owner"}, "roles" => []}],
    "voice_states" => [%{"user_id" => "1", "channel_id" => "7700000000000001010"}],
    "presences" => [],
    "stage_instances" => [],
    "guild_scheduled_events" => [],
    "soundboard_sounds" => []
  }

  describe "the struct" do
    test "keeps the fields of the guild object" do
      guild = EDA.Guild.from_raw(@guild_create)

      assert guild.features == ["COMMUNITY", "ANIMATED_ICON"]
      assert guild.premium_tier == :tier_2
      assert guild.premium_subscription_count == 9
      assert guild.banner == "banner_hash"
      assert guild.vanity_url_code == "test"
      assert guild.preferred_locale == "fr"
      assert guild.system_channel_id == "7700000000000001010"
      assert guild.rules_channel_id == "7700000000000001011"
      assert guild.mfa_level == :elevated
      assert guild.max_members == 500_000
      assert guild.incidents_data == %EDA.Guild.IncidentsData{}
      assert [%EDA.Emoji{name: "blob"}] = guild.emojis
    end

    test "GUILD_CREATE is an EDA.Guild, with the lists that only it carries, typed" do
      guild = EDA.Event.from_raw("GUILD_CREATE", @guild_create)

      assert %EDA.Guild{joined_at: ~U[2026-09-23 10:00:00.000000Z]} = guild
      assert [%EDA.Channel{name: "general"}] = guild.channels
      assert [%EDA.Channel{thread: %EDA.Channel.Thread{archived: false}}] = guild.threads
      assert [%EDA.Member{}] = guild.members
      assert [%EDA.VoiceState{user_id: "1"}] = guild.voice_states
    end

    test "GUILD_UPDATE is an EDA.Guild too" do
      assert %EDA.Guild{premium_tier: :tier_3} =
               EDA.Event.from_raw("GUILD_UPDATE", %{"id" => @guild_id, "premium_tier" => 3})
    end
  end

  describe "the cache" do
    setup do
      on_exit(fn -> EDA.Gateway.Events.dispatch("GUILD_DELETE", %{"id" => @guild_id}) end)
      EDA.Gateway.Events.dispatch("GUILD_CREATE", @guild_create)
      :ok
    end

    test "holds the guild object without the lists, which live in their own caches" do
      entry = EDA.Cache.get_guild(@guild_id)

      for key <- ["roles" | EDA.Guild.gateway_lists()] do
        refute Map.has_key?(entry, key), "the guild entry still holds #{key}"
      end

      assert entry["features"] == ["COMMUNITY", "ANIMATED_ICON"]
      assert EDA.Cache.get_member(@guild_id, "1")
      assert EDA.Cache.get_channel("7700000000000001010")
    end

    test "the active threads of GUILD_CREATE reach the channel cache" do
      assert %EDA.Channel{parent_id: "7700000000000001010"} =
               EDA.Cache.get_channel("7700000000000001020")
    end

    test "fetch/1 gives the current roles, not those of the join" do
      EDA.Gateway.Events.dispatch("GUILD_ROLE_CREATE", %{
        "guild_id" => @guild_id,
        "role" => %{"id" => "7700000000000001030", "name" => "Added later", "position" => 1}
      })

      {:ok, guild} = EDA.Guild.fetch(@guild_id)

      assert "Added later" in Enum.map(guild.roles, & &1.name)
      assert guild.members == nil
      assert guild.channels == nil
    end

    test "GUILD_UPDATE merges without bringing the lists back" do
      EDA.Gateway.Events.dispatch("GUILD_UPDATE", %{
        "id" => @guild_id,
        "name" => "Renamed",
        "roles" => [%{"id" => @guild_id, "name" => "@everyone"}]
      })

      entry = EDA.Cache.get_guild(@guild_id)
      assert entry["name"] == "Renamed"
      assert entry["premium_tier"] == :tier_2
      refute Map.has_key?(entry, "roles")
    end

    test "emoji and sticker updates reach the guild entry" do
      EDA.Gateway.Events.dispatch("GUILD_EMOJIS_UPDATE", %{
        "guild_id" => @guild_id,
        "emojis" => [%{"id" => "7700000000000001051", "name" => "new"}]
      })

      EDA.Gateway.Events.dispatch("GUILD_STICKERS_UPDATE", %{
        "guild_id" => @guild_id,
        "stickers" => [%{"id" => "7700000000000001060", "name" => "sticker"}]
      })

      {:ok, guild} = EDA.Guild.fetch(@guild_id)
      assert [%EDA.Emoji{name: "new"}] = guild.emojis
      assert [%EDA.Sticker{name: "sticker"}] = guild.stickers
    end
  end
end
