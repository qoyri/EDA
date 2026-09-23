defmodule EDA.UserBadgesTest do
  @moduledoc """
  Profile badges, avatar decorations, nameplates and member flags.

  The fixtures are a real user object read from the API on 2026-09-22, and the CDN paths were
  checked against it: the decoration answers 415 for `.gif` even though its hash is animated,
  and a nameplate has two files, `asset.webm` and `static.png`, neither in Discord's CDN table.
  """

  use ExUnit.Case, async: true

  import Bitwise

  doctest EDA.User.Flags
  doctest EDA.Member.Flags
  doctest EDA.User.AvatarDecoration
  doctest EDA.User.Nameplate
  doctest EDA.User.DisplayNameStyles

  alias EDA.User.{AvatarDecoration, Collectibles, Flags, Nameplate}

  @raw_user %{
    "id" => "776016158737432626",
    "username" => "qoyri",
    "public_flags" => 64,
    "avatar_decoration_data" => %{
      "asset" => "a_9ac0f841265e8ad6d5c31792aff69225",
      "sku_id" => "1385050947792801852",
      "expires_at" => nil
    },
    "collectibles" => %{
      "nameplate" => %{
        "asset" => "nameplates/zodiac/virgo/",
        "label" => "COLLECTIBLES_ZODIAC_VIRGO_NP_A11Y",
        "palette" => "lemon",
        "sku_id" => "1447654091097509950"
      }
    }
  }

  describe "EDA.User.Flags" do
    test "round-trips a bitset" do
      flags = [:staff, :partner, :active_developer]
      assert flags |> Flags.to_bitset() |> Flags.to_list() == flags
    end

    test "skips bits Discord does not document, rather than guessing" do
      # 1 <<< 5 is PREMIUM_PROMO_DISMISSED in unofficial tables, and has no badge.
      assert Flags.to_list(1 <<< 5 ||| 1 <<< 2) == [:hypesquad]
    end

    test "the three houses are separate flags, and none is the events flag" do
      assert length(Flags.houses()) == 3
      refute :hypesquad in Flags.houses()
      assert Enum.all?(Flags.houses(), &(Flags.to_list(Flags.to_bit(&1)) == [&1]))
    end

    test "an unknown flag raises rather than counting as absent" do
      assert_raise FunctionClauseError, fn -> Flags.to_bit(:nitro) end
      assert_raise FunctionClauseError, fn -> Flags.has?(1, :nitro) end
    end
  end

  describe "EDA.User badges" do
    test "reads a struct and a raw map alike" do
      user = EDA.User.from_raw(@raw_user)

      assert EDA.User.badges(user) == [:hypesquad_online_house_1]
      assert EDA.User.badges(@raw_user) == [:hypesquad_online_house_1]
      assert EDA.User.badge?(user, :hypesquad_online_house_1)
      refute EDA.User.badge?(user, :staff)
      assert EDA.User.badges(%EDA.User{}) == []
      refute EDA.User.badge?(%{"id" => "1"}, :staff)
    end
  end

  describe "avatar decoration" do
    test "parses into a struct, expiry included" do
      user = EDA.User.from_raw(@raw_user)

      assert %AvatarDecoration{asset: "a_" <> _, sku_id: "1385050947792801852", expires_at: nil} =
               user.avatar_decoration_data
    end

    test "an expiry is parsed from either shape Discord might send" do
      assert %AvatarDecoration{expires_at: ~U[2026-01-02 03:04:05Z]} =
               AvatarDecoration.from_raw(%{"expires_at" => "2026-01-02T03:04:05Z"})

      assert %AvatarDecoration{expires_at: %DateTime{}} =
               AvatarDecoration.from_raw(%{"expires_at" => 1_790_000_000})

      assert %AvatarDecoration{expires_at: nil} =
               AvatarDecoration.from_raw(%{"expires_at" => "not a date"})
    end

    test "the URL is PNG, animated hash included, and takes a size" do
      user = EDA.User.from_raw(@raw_user)

      assert EDA.User.avatar_decoration_url(user) ==
               "https://cdn.discordapp.com/avatar-decoration-presets/a_9ac0f841265e8ad6d5c31792aff69225.png"

      assert EDA.User.avatar_decoration_url(user, size: 256) =~ "?size=256"
      assert EDA.User.avatar_decoration_url(@raw_user) =~ "/avatar-decoration-presets/"
      assert EDA.User.avatar_decoration_url(%EDA.User{}) == nil
      assert EDA.User.avatar_decoration_url(%{"id" => "1"}) == nil
    end
  end

  describe "collectibles and nameplate" do
    test "parses into structs and keeps a kind it does not know" do
      user = EDA.User.from_raw(@raw_user)

      assert %Collectibles{nameplate: %Nameplate{palette: "lemon"}} = user.collectibles
      assert user.collectibles.nameplate.label == "COLLECTIBLES_ZODIAC_VIRGO_NP_A11Y"

      assert %Collectibles{nameplate: nil, other: %{"badge" => %{"asset" => "x"}}} =
               Collectibles.from_raw(%{"badge" => %{"asset" => "x"}})

      assert EDA.User.from_raw(%{"id" => "1"}).collectibles == nil
    end

    test "the URL is the animation by default and the still on request" do
      user = EDA.User.from_raw(@raw_user)
      base = "https://cdn.discordapp.com/assets/collectibles/nameplates/zodiac/virgo/"

      assert EDA.User.nameplate_url(user) == base <> "asset.webm"
      assert EDA.User.nameplate_url(user, format: :static) == base <> "static.png"
      assert EDA.User.nameplate_url(@raw_user) == base <> "asset.webm"
      assert EDA.User.nameplate_url(%EDA.User{}) == nil

      assert_raise ArgumentError, ~r/:animated or :static/, fn ->
        EDA.User.nameplate_url(user, format: :gif)
      end
    end
  end

  describe "member flags and fields" do
    @raw_member %{
      "user" => @raw_user,
      "roles" => ["1"],
      "flags" => 3,
      "premium_since" => "2026-01-01T00:00:00+00:00",
      "communication_disabled_until" => "2026-02-01T00:00:00+00:00",
      "avatar_decoration_data" => @raw_user["avatar_decoration_data"],
      "collectibles" => @raw_user["collectibles"]
    }

    test "the member carries flags, decoration and collectibles" do
      member = EDA.Member.from_raw(@raw_member)

      assert EDA.Member.flags(member) == [:did_rejoin, :completed_onboarding]
      assert EDA.Member.flag?(member, :did_rejoin)
      refute EDA.Member.flag?(member, :is_guest)
      assert %AvatarDecoration{} = member.avatar_decoration_data
      assert %Collectibles{nameplate: %Nameplate{}} = member.collectibles
      assert EDA.Member.flags(%EDA.Member{}) == []
      assert EDA.Member.flags(@raw_member) == [:did_rejoin, :completed_onboarding]
    end

    test "quarantine flags name what automod is hiding" do
      member = EDA.Member.from_raw(%{"flags" => 1 <<< 7 ||| 1 <<< 10})

      assert EDA.Member.flags(member) ==
               [:automod_quarantined_username, :automod_quarantined_guild_tag]
    end
  end

  describe "the member events" do
    test "GUILD_MEMBER_ADD carries the member's flags and boost date" do
      event =
        EDA.Event.from_raw("GUILD_MEMBER_ADD", %{
          "guild_id" => "1",
          "user" => @raw_user,
          "roles" => ["2"],
          "flags" => 1,
          "premium_since" => "2026-01-01T00:00:00+00:00",
          "communication_disabled_until" => "2026-02-01T00:00:00+00:00",
          "banner" => "b_hash"
        })

      assert event.flags == 1
      assert event.premium_since == "2026-01-01T00:00:00+00:00"
      assert event.communication_disabled_until == "2026-02-01T00:00:00+00:00"
      assert event.banner == "b_hash"

      # The event is the member itself, with its guild.
      assert %EDA.Member{roles: ["2"], banner: "b_hash", guild_id: "1"} = event
      assert EDA.Member.flags(event) == [:did_rejoin]
      assert event.user.id == "776016158737432626"
    end

    test "the member's own decoration, nameplate and name style come through" do
      event =
        EDA.Event.from_raw("GUILD_MEMBER_UPDATE", %{
          "guild_id" => "1",
          "user" => @raw_user,
          "avatar_decoration_data" => @raw_user["avatar_decoration_data"],
          "collectibles" => @raw_user["collectibles"],
          "display_name_styles" => %{"font_id" => 8, "effect_id" => 5, "colors" => [747_943]}
        })

      assert %AvatarDecoration{} = event.avatar_decoration_data
      assert %Collectibles{nameplate: %Nameplate{}} = event.collectibles

      assert %EDA.User.DisplayNameStyles{font_id: 8, colors: [747_943]} =
               event.display_name_styles
    end

    test "GUILD_MEMBER_UPDATE carries them too" do
      event =
        EDA.Event.from_raw("GUILD_MEMBER_UPDATE", %{
          "guild_id" => "1",
          "user" => @raw_user,
          "flags" => 4,
          "communication_disabled_until" => "2026-02-01T00:00:00+00:00",
          "banner" => "b_hash",
          "deaf" => false,
          "mute" => true
        })

      assert event.flags == 4
      assert event.communication_disabled_until == "2026-02-01T00:00:00+00:00"
      assert event.banner == "b_hash"
      assert event.mute == true
    end
  end
end
