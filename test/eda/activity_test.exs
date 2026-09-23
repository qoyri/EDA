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

    test "its parts are structs, its times DateTimes" do
      activity =
        Activity.from_raw(%{
          "type" => 2,
          "name" => "Spotify",
          "timestamps" => %{"start" => 1_758_600_000_000, "end" => 1_758_600_180_000},
          "assets" => %{"large_image" => "spotify:ab67", "large_text" => "Album"},
          "party" => %{"id" => "spotify:1", "size" => [1, 4]},
          "secrets" => %{"join" => "s3cr3t"},
          "buttons" => ["Listen along"]
        })

      assert activity.timestamps == %Activity.Timestamps{
               start: ~U[2025-09-23 04:00:00.000Z],
               end: ~U[2025-09-23 04:03:00.000Z]
             }

      assert %Activity.Assets{large_image: "spotify:ab67", large_text: "Album"} = activity.assets
      assert %Activity.Party{id: "spotify:1", size: [1, 4]} = activity.party
      assert %Activity.Secrets{join: "s3cr3t", spectate: nil} = activity.secrets
      assert activity.buttons == ["Listen along"]
      assert activity.timestamps["end"] == activity.timestamps.end
    end

    test "handles nil emoji" do
      activity = Activity.from_raw(%{"name" => "Test", "type" => 0})
      assert activity.emoji == nil
    end
  end
end
