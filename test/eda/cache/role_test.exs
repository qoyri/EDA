defmodule EDA.Cache.RoleTest do
  use ExUnit.Case

  describe "create/2 and get/1" do
    test "stores and retrieves a role" do
      role = %{"id" => "r1", "name" => "Admin", "color" => 0xFF0000, "permissions" => "8"}
      EDA.Cache.Role.create("rg1", role)

      cached = EDA.Cache.Role.get("r1")
      assert cached["name"] == "Admin"
      assert cached["guild_id"] == "rg1"
    end

    test "returns nil for unknown role" do
      assert EDA.Cache.Role.get("r_unknown") == nil
    end
  end

  describe "for_guild/1" do
    test "returns roles for a specific guild" do
      EDA.Cache.Role.create("rfg", %{"id" => "rfg_1", "name" => "Mod"})
      EDA.Cache.Role.create("rfg", %{"id" => "rfg_2", "name" => "Member"})
      EDA.Cache.Role.create("rfg_other", %{"id" => "rfg_3", "name" => "Other"})

      roles = EDA.Cache.Role.for_guild("rfg")
      assert length(roles) >= 2
      names = Enum.map(roles, & &1["name"])
      assert "Mod" in names
      assert "Member" in names
    end
  end

  describe "update/2" do
    test "merges fields into existing role" do
      EDA.Cache.Role.create("rug", %{"id" => "rug_1", "name" => "Old", "color" => 0})
      EDA.Cache.Role.update("rug_1", %{"name" => "New"})

      cached = EDA.Cache.Role.get("rug_1")
      assert cached["name"] == "New"
      assert cached["color"] == 0
    end
  end

  describe "delete/1" do
    test "removes a role" do
      EDA.Cache.Role.create("rdg", %{"id" => "rd_1", "name" => "Gone"})
      EDA.Cache.Role.delete("rd_1")
      assert EDA.Cache.Role.get("rd_1") == nil
    end
  end

  describe "delete_guild/1" do
    test "removes all roles for a guild" do
      EDA.Cache.Role.create("rdgg", %{"id" => "rdgg_1", "name" => "A"})
      EDA.Cache.Role.create("rdgg", %{"id" => "rdgg_2", "name" => "B"})

      EDA.Cache.Role.delete_guild("rdgg")
      assert EDA.Cache.Role.for_guild("rdgg") == []
    end
  end

  describe "Cache facade" do
    test "get_role delegates correctly" do
      EDA.Cache.Role.create("rf_g", %{"id" => "rf_1", "name" => "Facade"})

      role = EDA.Cache.get_role("rf_1")
      assert role["name"] == "Facade"
    end

    test "roles delegates correctly" do
      EDA.Cache.Role.create("rf_g2", %{"id" => "rf_2", "name" => "A"})

      roles = EDA.Cache.roles("rf_g2")
      assert roles != []
    end
  end
end
