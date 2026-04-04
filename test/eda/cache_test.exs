defmodule EDA.CacheTest do
  use ExUnit.Case

  # Cache GenServers are already started by the application supervisor.
  # Tests are NOT async because they share ETS tables.

  describe "Guild cache" do
    test "create and get" do
      guild = %{"id" => "111", "name" => "Test Guild"}
      EDA.Cache.Guild.create(guild)

      assert EDA.Cache.Guild.get("111") == guild
    end

    test "get returns nil for missing guild" do
      assert EDA.Cache.Guild.get("nonexistent") == nil
    end

    test "accepts integer IDs" do
      guild = %{"id" => 222, "name" => "Int ID Guild"}
      EDA.Cache.Guild.create(guild)

      assert EDA.Cache.Guild.get(222) != nil
      assert EDA.Cache.Guild.get("222") != nil
    end

    test "update merges fields" do
      EDA.Cache.Guild.create(%{"id" => "333", "name" => "Old Name", "region" => "us-east"})
      EDA.Cache.Guild.update("333", %{"name" => "New Name"})

      updated = EDA.Cache.Guild.get("333")
      assert updated["name"] == "New Name"
      assert updated["region"] == "us-east"
    end

    test "update returns nil for missing guild" do
      assert EDA.Cache.Guild.update("missing", %{"name" => "X"}) == nil
    end

    test "delete removes guild" do
      EDA.Cache.Guild.create(%{"id" => "444", "name" => "To Delete"})
      assert EDA.Cache.Guild.get("444") != nil

      EDA.Cache.Guild.delete("444")
      assert EDA.Cache.Guild.get("444") == nil
    end

    test "all returns all cached guilds" do
      EDA.Cache.Guild.create(%{"id" => "a1", "name" => "G1"})
      EDA.Cache.Guild.create(%{"id" => "a2", "name" => "G2"})

      all = EDA.Cache.Guild.all()
      assert length(all) >= 2
      ids = Enum.map(all, & &1["id"])
      assert "a1" in ids
      assert "a2" in ids
    end

    test "count returns number of guilds" do
      initial = EDA.Cache.Guild.count()
      EDA.Cache.Guild.create(%{"id" => "c1", "name" => "Count Test"})
      assert EDA.Cache.Guild.count() == initial + 1
    end
  end

  describe "User cache" do
    test "create and get" do
      user = %{"id" => "u1", "username" => "testuser"}
      EDA.Cache.User.create(user)

      assert EDA.Cache.User.get("u1") == user
    end

    test "get returns nil for missing user" do
      assert EDA.Cache.User.get("nonexistent") == nil
    end

    test "delete removes user" do
      EDA.Cache.User.create(%{"id" => "u2", "username" => "delete_me"})
      EDA.Cache.User.delete("u2")
      assert EDA.Cache.User.get("u2") == nil
    end

    test "count returns number of users" do
      initial = EDA.Cache.User.count()
      EDA.Cache.User.create(%{"id" => "u_count", "username" => "counter"})
      assert EDA.Cache.User.count() == initial + 1
    end
  end

  describe "Channel cache" do
    test "create and get" do
      channel = %{"id" => "ch1", "name" => "general", "guild_id" => "g1"}
      EDA.Cache.Channel.create(channel)

      assert EDA.Cache.Channel.get("ch1") == channel
    end

    test "for_guild filters by guild_id" do
      EDA.Cache.Channel.create(%{"id" => "ch_g1_a", "name" => "a", "guild_id" => "fg1"})
      EDA.Cache.Channel.create(%{"id" => "ch_g1_b", "name" => "b", "guild_id" => "fg1"})
      EDA.Cache.Channel.create(%{"id" => "ch_g2_a", "name" => "c", "guild_id" => "fg2"})

      g1_channels = EDA.Cache.Channel.for_guild("fg1")
      assert length(g1_channels) == 2
      ids = Enum.map(g1_channels, & &1["id"])
      assert "ch_g1_a" in ids
      assert "ch_g1_b" in ids
    end

    test "delete removes channel" do
      EDA.Cache.Channel.create(%{"id" => "ch_del", "name" => "x"})
      EDA.Cache.Channel.delete("ch_del")
      assert EDA.Cache.Channel.get("ch_del") == nil
    end
  end

  describe "me/put_me" do
    test "stores and retrieves bot user as struct" do
      user = %{"id" => "bot_id", "username" => "TestBot"}
      EDA.Cache.put_me(user)

      me = EDA.Cache.me()
      assert %EDA.User{id: "bot_id", username: "TestBot"} = me
    end

    test "me_raw returns the original map" do
      user = %{"id" => "bot_id_raw", "username" => "RawBot"}
      EDA.Cache.put_me(user)

      assert EDA.Cache.me_raw() == user
    end
  end
end
