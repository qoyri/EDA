defmodule EDA.PermissionOverwriteTest do
  use ExUnit.Case, async: true

  alias EDA.PermissionOverwrite

  describe "from_raw/1" do
    test "parses all fields" do
      raw = %{"id" => "123", "type" => 0, "allow" => "104320", "deny" => "8192"}
      po = PermissionOverwrite.from_raw(raw)
      assert %PermissionOverwrite{} = po
      assert po.id == "123"
      assert po.type == :role
      assert po.allow == "104320"
      assert po.deny == "8192"
    end

    test "handles missing fields" do
      po = PermissionOverwrite.from_raw(%{"id" => "1"})
      assert po.type == nil
      assert po.allow == nil
    end
  end
end
