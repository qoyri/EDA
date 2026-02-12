defmodule EDA.Cache.PresenceTest do
  use ExUnit.Case

  describe "upsert/2 and get/2" do
    test "stores and retrieves a presence" do
      EDA.Cache.Presence.upsert("pg1", %{
        "user" => %{"id" => "pu1"},
        "status" => "online",
        "activities" => [%{"name" => "Playing a game"}]
      })

      presence = EDA.Cache.Presence.get("pg1", "pu1")
      assert presence["status"] == "online"
      assert presence["guild_id"] == "pg1"
    end

    test "returns nil for unknown presence" do
      assert EDA.Cache.Presence.get("p_unknown", "p_unknown") == nil
    end

    test "updates existing presence" do
      EDA.Cache.Presence.upsert("pg2", %{
        "user" => %{"id" => "pu2"},
        "status" => "online"
      })

      EDA.Cache.Presence.upsert("pg2", %{
        "user" => %{"id" => "pu2"},
        "status" => "idle"
      })

      presence = EDA.Cache.Presence.get("pg2", "pu2")
      assert presence["status"] == "idle"
    end
  end

  describe "for_guild/1" do
    test "returns all presences for a guild" do
      EDA.Cache.Presence.upsert("pfg", %{"user" => %{"id" => "pfg_1"}, "status" => "online"})
      EDA.Cache.Presence.upsert("pfg", %{"user" => %{"id" => "pfg_2"}, "status" => "dnd"})

      presences = EDA.Cache.Presence.for_guild("pfg")
      assert length(presences) >= 2
    end
  end

  describe "delete_guild/1" do
    test "removes all presences for a guild" do
      EDA.Cache.Presence.upsert("pdg", %{"user" => %{"id" => "pdg_1"}, "status" => "online"})
      EDA.Cache.Presence.upsert("pdg", %{"user" => %{"id" => "pdg_2"}, "status" => "idle"})

      EDA.Cache.Presence.delete_guild("pdg")
      assert EDA.Cache.Presence.for_guild("pdg") == []
    end
  end

  describe "Cache facade" do
    test "get_presence delegates correctly" do
      EDA.Cache.Presence.upsert("pf_g", %{
        "user" => %{"id" => "pf_u"},
        "status" => "dnd"
      })

      presence = EDA.Cache.get_presence("pf_g", "pf_u")
      assert presence["status"] == "dnd"
    end
  end
end
