defmodule EDA.PresenceClientStatusTest do
  @moduledoc """
  Which platforms a user is connected from, read off `client_status`.

  The shapes here are the ones seen live on 2026-09-23 across 90 cached presences: one key per
  active session, `web` for almost every bot, and an `embedded` key Discord does not document.
  """

  use ExUnit.Case, async: true

  alias EDA.Presence

  doctest EDA.Presence, only: [platforms: 1, status_on: 2, on?: 2, platform: 1]

  defp presence(client_status),
    do: %{"status" => "online", "activities" => [], "client_status" => client_status}

  describe "platforms/1" do
    test "one key per active session, in a stable order" do
      assert Presence.platforms(presence(%{"mobile" => "online", "desktop" => "idle"})) ==
               [:desktop, :mobile]

      assert Presence.platforms(presence(%{"web" => "dnd"})) == [:web]
    end

    test "an offline or invisible user has none, which are the same thing here" do
      assert Presence.platforms(%{"status" => "offline", "activities" => []}) == []
      assert Presence.platforms(presence(%{})) == []
      assert Presence.platforms(nil) == []
    end

    test "the embedded session Discord sends but does not document is named" do
      assert Presence.platforms(presence(%{"embedded" => "online"})) == [:embedded]
    end

    test "a platform Discord adds later is kept as its string, after the known ones" do
      assert Presence.platforms(presence(%{"watch" => "online", "mobile" => "dnd"})) ==
               [:mobile, "watch"]

      # and on its own, where there is nothing known to recognise the map by
      assert Presence.platforms(%{"watch" => "online"}) == ["watch"]
    end

    test "reads the event and the client_status map alike" do
      event = EDA.Event.from_raw("PRESENCE_UPDATE", presence(%{"desktop" => "dnd"}))

      assert Presence.platforms(event) == [:desktop]
      assert Presence.platforms(%{"desktop" => "dnd"}) == [:desktop]
    end
  end

  describe "status_on/2 and on?/2" do
    test "the status of one session, or nil when there is none" do
      p = presence(%{"mobile" => "dnd", "desktop" => "idle", "web" => "online"})

      assert Presence.status_on(p, :mobile) == :dnd
      assert Presence.status_on(p, :desktop) == :idle
      assert Presence.status_on(p, :web) == :online
      assert Presence.status_on(p, :vr) == nil
      assert Presence.status_on(nil, :web) == nil
    end

    test "a status Discord has not used before does not become a session" do
      assert Presence.status_on(presence(%{"mobile" => "sleeping"}), :mobile) == nil
    end

    test "the shorthands agree with on?/2" do
      p = presence(%{"mobile" => "online", "web" => "idle"})

      assert Presence.mobile?(p)
      assert Presence.web?(p)
      refute Presence.desktop?(p)
      assert Presence.on?(p, :mobile)
      refute Presence.on?(p, :vr)
    end

    test "an unknown platform can be asked about by its string" do
      assert Presence.status_on(presence(%{"watch" => "online"}), "watch") == :online
      assert Presence.on?(presence(%{"watch" => "online"}), "watch")
    end
  end

  describe "the presence struct is not confused with someone else's presence" do
    test "building the bot's own presence still works" do
      p = Presence.new(status: :dnd, activities: [Presence.playing("Elixir")])

      assert Presence.platforms(p) == []
      assert Presence.to_map(p).status == "dnd"
    end
  end

  test "PRESENCE_UPDATE names the status and each platform's status" do
    event =
      EDA.Event.from_raw("PRESENCE_UPDATE", %{
        "user" => %{"id" => "1"},
        "status" => "dnd",
        "client_status" => %{"desktop" => "dnd", "mobile" => "idle", "watch" => "online"}
      })

    assert event.status == :dnd
    assert event.client_status == %{:desktop => :dnd, :mobile => :idle, "watch" => :online}
    assert Presence.platforms(event) == [:desktop, :mobile, "watch"]
    assert Presence.status_on(event, :mobile) == :idle
    assert EDA.Event.from_raw("PRESENCE_UPDATE", %{"status" => "offline"}).status == :offline
  end
end
