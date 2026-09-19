defmodule EDA.UserPrimaryGuildTest do
  use ExUnit.Case, async: true

  alias EDA.User
  alias EDA.User.PrimaryGuild

  doctest EDA.User.PrimaryGuild

  # Shape taken verbatim from a real guild (2026-09-19).
  @raw_primary_guild %{
    "identity_guild_id" => "1508992262657409046",
    "identity_enabled" => true,
    "tag" => "BABL",
    "badge" => "22957f5661c149eefe1ba25d2bec7060"
  }

  describe "from_raw/1" do
    test "parses the four documented keys" do
      pg = PrimaryGuild.from_raw(@raw_primary_guild)

      assert pg.identity_guild_id == "1508992262657409046"
      assert pg.identity_enabled == true
      assert pg.tag == "BABL"
      assert pg.badge == "22957f5661c149eefe1ba25d2bec7060"
    end

    test "nil gives nil — the key is present on every user but usually null" do
      assert PrimaryGuild.from_raw(nil) == nil
    end
  end

  describe "displayed?/1" do
    test "true only when enabled with a tag" do
      assert PrimaryGuild.displayed?(%PrimaryGuild{identity_enabled: true, tag: "ABCD"})
    end

    test "false when the user removed it manually" do
      refute PrimaryGuild.displayed?(%PrimaryGuild{identity_enabled: false, tag: "ABCD"})
    end

    test "false when Discord cleared the identity (nil, not false)" do
      refute PrimaryGuild.displayed?(%PrimaryGuild{identity_enabled: nil, tag: "ABCD"})
    end

    test "false when enabled but there is no tag" do
      refute PrimaryGuild.displayed?(%PrimaryGuild{identity_enabled: true, tag: nil})
    end
  end

  describe "badge_url/2" do
    test "builds the documented CDN route" do
      assert PrimaryGuild.badge_url(PrimaryGuild.from_raw(@raw_primary_guild)) ==
               "https://cdn.discordapp.com/guild-tag-badges/1508992262657409046/22957f5661c149eefe1ba25d2bec7060.png"
    end

    test "honours :size" do
      url = PrimaryGuild.badge_url(PrimaryGuild.from_raw(@raw_primary_guild), size: 128)

      assert String.ends_with?(url, ".png?size=128")
    end

    test "nil without a badge or a guild id" do
      assert PrimaryGuild.badge_url(%PrimaryGuild{identity_guild_id: "1", badge: nil}) == nil
      assert PrimaryGuild.badge_url(%PrimaryGuild{identity_guild_id: nil, badge: "x"}) == nil
      assert PrimaryGuild.badge_url(nil) == nil
    end
  end

  describe "raw map support — EDA.Cache.users/0 returns maps, not structs" do
    test "server_tag/1 reads a raw user map, like display_name/1 does" do
      assert User.server_tag(%{"primary_guild" => @raw_primary_guild}) == "BABL"
    end

    test "server_tag/1 respects identity_enabled on a raw map" do
      hidden = Map.put(@raw_primary_guild, "identity_enabled", false)

      assert User.server_tag(%{"primary_guild" => hidden}) == nil
    end

    test "server_tag/1 is nil for a raw map without the key, or a null value" do
      assert User.server_tag(%{"id" => "1"}) == nil
      assert User.server_tag(%{"primary_guild" => nil}) == nil
    end

    test "guild_tag_badge_url/2 works from a struct and from a raw map" do
      expected =
        "https://cdn.discordapp.com/guild-tag-badges/1508992262657409046/22957f5661c149eefe1ba25d2bec7060.png"

      struct_user = User.from_raw(%{"id" => "1", "primary_guild" => @raw_primary_guild})

      assert User.guild_tag_badge_url(struct_user) == expected
      assert User.guild_tag_badge_url(%{"primary_guild" => @raw_primary_guild}) == expected
    end

    test "guild_tag_badge_url/2 forwards :size" do
      url = User.guild_tag_badge_url(%{"primary_guild" => @raw_primary_guild}, size: 64)

      assert String.ends_with?(url, "?size=64")
    end

    test "guild_tag_badge_url/2 is nil without a primary guild" do
      assert User.guild_tag_badge_url(%User{}) == nil
      assert User.guild_tag_badge_url(%{"id" => "1"}) == nil
    end
  end

  describe "EDA.User integration" do
    test "from_raw/1 parses primary_guild into a struct" do
      user =
        User.from_raw(%{
          "id" => "1",
          "username" => "someone",
          "primary_guild" => @raw_primary_guild
        })

      assert %PrimaryGuild{} = user.primary_guild
      assert user.primary_guild.tag == "BABL"
    end

    test "a null primary_guild is the common case and parses to nil" do
      user = User.from_raw(%{"id" => "1", "username" => "someone", "primary_guild" => nil})

      assert user.primary_guild == nil
      assert User.server_tag(user) == nil
    end

    test "a user object without the key at all still parses" do
      assert User.from_raw(%{"id" => "1", "username" => "someone"}).primary_guild == nil
    end

    test "server_tag/1 returns the tag only when displayed" do
      shown = User.from_raw(%{"id" => "1", "primary_guild" => @raw_primary_guild})
      hidden_raw = Map.put(@raw_primary_guild, "identity_enabled", false)
      hidden = User.from_raw(%{"id" => "2", "primary_guild" => hidden_raw})

      assert User.server_tag(shown) == "BABL"
      assert User.server_tag(hidden) == nil
    end
  end
end
