defmodule EDA.ScheduledEventTest do
  @moduledoc """
  The scheduled event events deliver an `EDA.ScheduledEvent`, cover image and recurrence rule
  included; their structs used to drop both and keep the creator as a raw map. Payload per the
  guild scheduled event reference.
  """

  use ExUnit.Case, async: true

  doctest EDA.ScheduledEvent.RecurrenceRule

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

      assert %EDA.ScheduledEvent.RecurrenceRule{frequency: :weekly, by_weekday: [:friday]} =
               event.recurrence_rule

      assert %EDA.User{username: "host"} = event.creator
      assert event.entity_metadata["location"] == "Online"
    end
  end

  test "a recurrence rule reads every field, and is sent as Discord takes it" do
    raw = %{
      "start" => "2026-10-01T18:00:00+00:00",
      "end" => nil,
      "frequency" => 0,
      "interval" => 1,
      "by_weekday" => nil,
      "by_n_weekday" => nil,
      "by_month" => [7],
      "by_month_day" => [14],
      "by_year_day" => [195],
      "count" => nil
    }

    rule = EDA.ScheduledEvent.RecurrenceRule.from_raw(raw)

    assert %EDA.ScheduledEvent.RecurrenceRule{
             frequency: :yearly,
             by_month: [:july],
             by_month_day: [14],
             start: ~U[2026-10-01 18:00:00Z]
           } = rule

    assert rule |> Jason.encode!() |> Jason.decode!() == %{
             "start" => "2026-10-01T18:00:00Z",
             "frequency" => 0,
             "interval" => 1,
             "by_month" => [7],
             "by_month_day" => [14],
             "by_year_day" => [195]
           }

    assert Jason.encode!(%EDA.ScheduledEvent.EntityMetadata{location: "Paris"}) ==
             ~s({"location":"Paris"})
  end
end
