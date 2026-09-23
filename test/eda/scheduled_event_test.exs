defmodule EDA.ScheduledEventTest do
  @moduledoc """
  The scheduled event events deliver an `EDA.ScheduledEvent`, cover image and recurrence rule
  included; their structs used to drop both and keep the creator as a raw map. Payload per the
  guild scheduled event reference.
  """

  use ExUnit.Case, async: true

  @payload %{
    "id" => "1",
    "guild_id" => "2",
    "channel_id" => nil,
    "creator_id" => "3",
    "name" => "Game night",
    "scheduled_start_time" => "2026-09-25T20:00:00+00:00",
    "scheduled_end_time" => "2026-09-25T23:00:00+00:00",
    "privacy_level" => 2,
    "status" => 1,
    "entity_type" => 3,
    "entity_id" => nil,
    "entity_metadata" => %{"location" => "Online"},
    "creator" => %{"id" => "3", "username" => "host"},
    "user_count" => 12,
    "image" => "cover_hash",
    "recurrence_rule" => %{"frequency" => 2, "interval" => 1, "by_weekday" => [4]}
  }

  for name <- ~w(GUILD_SCHEDULED_EVENT_CREATE GUILD_SCHEDULED_EVENT_UPDATE
                 GUILD_SCHEDULED_EVENT_DELETE) do
    test "#{name} is an EDA.ScheduledEvent" do
      event = EDA.Event.from_raw(unquote(name), @payload)

      assert %EDA.ScheduledEvent{name: "Game night", user_count: 12} = event
      assert event.image == "cover_hash"
      assert %{"frequency" => 2} = event.recurrence_rule
      assert %EDA.User{username: "host"} = event.creator
      assert event.entity_metadata["location"] == "Online"
    end
  end
end
