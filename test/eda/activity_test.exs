defmodule EDA.ActivityTest do
  use ExUnit.Case, async: true

  alias EDA.Activity

  describe "from_raw/1" do
    test "parses all fields with nested emoji" do
      raw = %{
        "name" => "Playing",
        "type" => 0,
        "url" => nil,
        "created_at" => 1_234_567,
        "application_id" => "app1",
        "details" => "In Game",
        "state" => "Playing Solo",
        "emoji" => %{"id" => "e1", "name" => "game"},
        "flags" => 1
      }

      activity = Activity.from_raw(raw)
      assert %Activity{} = activity
      assert activity.name == "Playing"
      assert activity.type == :playing
      assert activity.created_at == ~U[1970-01-01 00:20:34.567Z]
      assert %EDA.Emoji{id: "e1", name: "game"} = activity.emoji
    end

    test "handles nil emoji" do
      activity = Activity.from_raw(%{"name" => "Test", "type" => 0})
      assert activity.emoji == nil
    end
  end
end
