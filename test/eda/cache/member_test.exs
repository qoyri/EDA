defmodule EDA.Cache.MemberTest do
  use ExUnit.Case

  describe "create/2 and get/2" do
    test "stores and retrieves a member" do
      member = %{
        "user" => %{"id" => "m_u1", "username" => "test"},
        "nick" => "Tester",
        "roles" => ["role1", "role2"],
        "joined_at" => "2024-01-01T00:00:00Z"
      }

      EDA.Cache.Member.create("m_g1", member)

      cached = EDA.Cache.Member.get("m_g1", "m_u1")
      assert cached["nick"] == "Tester"
      assert cached["guild_id"] == "m_g1"
      assert cached["roles"] == ["role1", "role2"]
    end

    test "returns nil for unknown member" do
      assert EDA.Cache.Member.get("m_unknown", "m_unknown") == nil
    end
  end

  describe "update/3" do
    test "merges fields into existing member" do
      EDA.Cache.Member.create("m_g2", %{
        "user" => %{"id" => "m_u2"},
        "nick" => "Old",
        "roles" => ["r1"]
      })

      EDA.Cache.Member.update("m_g2", "m_u2", %{"nick" => "New"})

      cached = EDA.Cache.Member.get("m_g2", "m_u2")
      assert cached["nick"] == "New"
      assert cached["roles"] == ["r1"]
    end

    test "returns nil for unknown member" do
      assert EDA.Cache.Member.update("m_none", "m_none", %{}) == nil
    end
  end

  describe "for_guild/1" do
    test "returns all members for a guild" do
      EDA.Cache.Member.create("m_fg", %{"user" => %{"id" => "fg_1"}})
      EDA.Cache.Member.create("m_fg", %{"user" => %{"id" => "fg_2"}})
      EDA.Cache.Member.create("m_fg", %{"user" => %{"id" => "fg_3"}})

      members = EDA.Cache.Member.for_guild("m_fg")
      assert length(members) >= 3
    end
  end

  describe "delete/2" do
    test "removes a member" do
      EDA.Cache.Member.create("m_gd", %{"user" => %{"id" => "md_u1"}})
      EDA.Cache.Member.delete("m_gd", "md_u1")
      assert EDA.Cache.Member.get("m_gd", "md_u1") == nil
    end
  end

  describe "delete_guild/1" do
    test "removes all members for a guild" do
      EDA.Cache.Member.create("m_dg", %{"user" => %{"id" => "dg_1"}})
      EDA.Cache.Member.create("m_dg", %{"user" => %{"id" => "dg_2"}})

      EDA.Cache.Member.delete_guild("m_dg")
      assert EDA.Cache.Member.for_guild("m_dg") == []
    end
  end

  describe "Cache facade" do
    test "get_member delegates correctly" do
      EDA.Cache.Member.create("mf_g", %{
        "user" => %{"id" => "mf_u"},
        "nick" => "Facade"
      })

      member = EDA.Cache.get_member("mf_g", "mf_u")
      assert member["nick"] == "Facade"
    end
  end
end
