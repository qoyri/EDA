defmodule EDA.CDNTest do
  @moduledoc """
  Image URLs on Discord's CDN, checked against the CDN itself on 2026-09-23: an animated hash
  (`a_`) serves GIF and animated WebP, a still one answers 415 to `.gif`, and every image takes
  `?size=`. `EDA.User.avatar_url/1` used to return `.png` for every avatar, animated or not.
  """

  use ExUnit.Case, async: true

  doctest EDA.User
  doctest EDA.Guild
  doctest EDA.Emoji
  doctest EDA.Role, only: [icon_url: 2]
  doctest EDA.Member, only: [avatar_url: 2, display_avatar_url: 2]
  doctest EDA.ScheduledEvent, only: [cover_url: 2]
  doctest EDA.Team

  test "an animated avatar is a GIF, and its still can be asked for" do
    user = %EDA.User{id: "1", avatar: "a_abc"}

    assert EDA.User.avatar_url(user) == "https://cdn.discordapp.com/avatars/1/a_abc.gif"

    assert EDA.User.avatar_url(user, animated: false) ==
             "https://cdn.discordapp.com/avatars/1/a_abc.png"

    assert EDA.User.avatar_url(%{"id" => "1", "avatar" => "a_abc"}) =~ ".gif"
  end

  test "a still image has no GIF, and Discord would answer 415" do
    assert_raise ArgumentError, ~r/not animated/, fn ->
      EDA.User.avatar_url(%EDA.User{id: "1", avatar: "abc"}, format: :gif)
    end
  end

  test "the size is a power of two from 16 to 4096" do
    assert EDA.Guild.icon_url(%EDA.Guild{id: "1", icon: "abc"}, size: 4096) =~ "?size=4096"

    for bad <- [8, 100, 8192] do
      assert_raise ArgumentError, ~r/power of two/, fn ->
        EDA.Guild.icon_url(%EDA.Guild{id: "1", icon: "abc"}, size: bad)
      end
    end
  end

  test "an emoji, animated or not, in the format Discord recommends" do
    assert EDA.Emoji.image_url(%EDA.Emoji{id: "5", animated: true}, format: :webp) ==
             "https://cdn.discordapp.com/emojis/5.webp?animated=true"

    assert EDA.Emoji.image_url(%EDA.Emoji{id: "5"}, format: :webp, size: 64) ==
             "https://cdn.discordapp.com/emojis/5.webp?size=64"
  end

  test "an unknown format is refused" do
    assert_raise ArgumentError, ~r/:png, :jpg, :webp or :gif/, fn ->
      EDA.User.avatar_url(%EDA.User{id: "1", avatar: "abc"}, format: :bmp)
    end
  end

  test "the default avatar of an account that still has a discriminator comes from it" do
    assert EDA.User.default_avatar_url(%EDA.User{id: "1", discriminator: "1337"}) ==
             "https://cdn.discordapp.com/embed/avatars/2.png"

    assert EDA.User.default_avatar_url(%{"id" => "80351110224678912", "discriminator" => "0"}) ==
             "https://cdn.discordapp.com/embed/avatars/5.png"
  end

  test "a member without a guild avatar shows their account's, and without either the default" do
    member = %EDA.Member{
      guild_id: "1",
      user: %EDA.User{id: "80351110224678912", discriminator: "0"}
    }

    assert EDA.Member.avatar_url(member) == nil

    assert EDA.Member.display_avatar_url(member) ==
             "https://cdn.discordapp.com/embed/avatars/5.png"
  end
end
