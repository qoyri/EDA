defmodule EDA.UserPremiumTest do
  @moduledoc """
  Covers the user fields `from_raw/1` used to drop, and the Nitro tier naming.

  `premium_type` is unusual: it needs the `identify.premium` OAuth2 scope, so it is absent
  from every user a bot sees through the gateway or the REST API. "Absent" and "no Nitro"
  are different answers, and the tests pin that distinction down because collapsing them
  would silently tell a bot that every user it has ever seen is a free user.
  """

  use ExUnit.Case, async: true

  alias EDA.User

  doctest EDA.User, only: [premium_type: 1, nitro?: 1]

  describe "premium_type/1" do
    test "names every documented tier" do
      assert User.premium_type(%User{premium_type: 0}) == :none
      assert User.premium_type(%User{premium_type: 1}) == :nitro_classic
      assert User.premium_type(%User{premium_type: 2}) == :nitro
      assert User.premium_type(%User{premium_type: 3}) == :nitro_basic
    end

    test "absent is nil, not :none — the scope was simply not granted" do
      assert User.premium_type(%User{}) == nil
      assert User.premium_type(%{"id" => "1"}) == nil
      assert User.premium_type(nil) == nil

      # and :none is a real answer meaning the user has no Nitro
      assert User.premium_type(%User{premium_type: 0}) == :none
    end

    test "reads a raw map and a bare integer too" do
      assert User.premium_type(%{"premium_type" => 2}) == :nitro
      assert User.premium_type(2) == :nitro
    end

    test "a tier Discord adds later does not crash a case" do
      assert User.premium_type(%User{premium_type: 99}) == :unknown
    end
  end

  describe "nitro?/1" do
    test "true for the three paid tiers" do
      for value <- [1, 2, 3], do: assert(User.nitro?(%User{premium_type: value}))
    end

    test "false for no Nitro and for not knowing" do
      refute User.nitro?(%User{premium_type: 0})
      refute User.nitro?(%User{})
      refute User.nitro?(%User{premium_type: 99})
    end
  end

  describe "display_name/1 versus Discord's raw display_name" do
    test "falls back to the username where the raw field would be null" do
      # Measured live on 2026-09-19: 46 of 573 users had display_name: null, every bot
      # among them. A caller reading the raw field would get nil for all of those.
      raw = %{"id" => "u1", "username" => "Statbot", "global_name" => nil, "display_name" => nil}

      assert User.display_name(raw) == "Statbot"
      assert User.display_name(User.from_raw(raw)) == "Statbot"
    end

    test "prefers the global name when there is one" do
      raw = %{"id" => "u1", "username" => "someone", "global_name" => "Someone"}

      assert User.display_name(raw) == "Someone"
    end
  end

  describe "from_raw/1 keeps the rest of the user object" do
    test "the fields that were being dropped" do
      user =
        User.from_raw(%{
          "id" => "u1",
          "username" => "someone",
          "premium_type" => 2,
          "mfa_enabled" => true,
          "locale" => "fr",
          "verified" => true,
          "email" => "someone@example.com",
          "avatar_decoration_data" => %{"asset" => "a_deco", "sku_id" => "sku1"},
          "collectibles" => %{"nameplate" => %{"asset" => "np"}}
        })

      assert user.premium_type == :nitro
      assert user.mfa_enabled == true
      assert user.locale == "fr"
      assert user.verified == true
      assert user.email == "someone@example.com"
      assert user.avatar_decoration_data["asset"] == "a_deco"
      assert user.collectibles["nameplate"]["asset"] == "np"
    end

    test "a plain gateway user has none of them, and parses fine" do
      user = User.from_raw(%{"id" => "u1", "username" => "someone"})

      assert user.premium_type == nil
      assert user.mfa_enabled == nil
      assert user.locale == nil
      assert user.verified == nil
      assert user.email == nil
      assert user.avatar_decoration_data == nil
      assert user.collectibles == nil
    end

    # These are structs since the badges work, and the string-key reads that code written
    # against the raw maps uses still resolve, through EDA.Event.Access.
    test "the nested objects answer to string keys, per the struct contract" do
      user = User.from_raw(%{"id" => "u1", "collectibles" => %{"nameplate" => %{"asset" => "x"}}})

      assert user.collectibles["nameplate"]["asset"] == "x"
      assert user["collectibles"]["nameplate"]["asset"] == "x"
      assert %EDA.User.Nameplate{asset: "x"} = user.collectibles.nameplate
    end
  end
end
