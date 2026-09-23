defmodule EDA.InteractionFieldsTest do
  @moduledoc """
  `INTERACTION_CREATE` keeps every field of the interaction object.

  `context`, `authorizing_integration_owners`, `attachment_size_limit`, the partial `guild` and
  `channel` were dropped — what a user-installed command needs to know where it runs and who
  installed it. Payload per the interactions reference.
  """

  use ExUnit.Case, async: true

  @payload %{
    "id" => "1",
    "application_id" => "2",
    "type" => 2,
    "token" => "t",
    "version" => 1,
    "channel_id" => "3",
    "channel" => %{"id" => "3", "type" => 1},
    "guild" => %{"id" => "4", "locale" => "fr", "features" => ["COMMUNITY"]},
    "user" => %{"id" => "5"},
    "app_permissions" => "0",
    "entitlements" => [%{"id" => "6", "sku_id" => "7", "type" => 8}],
    "context" => 1,
    "authorizing_integration_owners" => %{"0" => "0", "1" => "5"},
    "attachment_size_limit" => 10_485_760
  }

  test "where it came from and who authorised it" do
    event = EDA.Event.from_raw("INTERACTION_CREATE", @payload)

    assert event.context == :bot_dm
    assert event.authorizing_integration_owners == %{guild_install: "0", user_install: "5"}
    assert event.attachment_size_limit == 10_485_760
    assert event.version == 1
  end

  test "the partial guild and channel, and the entitlements, are structs" do
    event = EDA.Event.from_raw("INTERACTION_CREATE", @payload)

    assert %EDA.Guild{preferred_locale: "fr", features: ["COMMUNITY"]} = event.guild
    assert %EDA.Channel{type: :dm} = event.channel
    assert [%EDA.Entitlement{id: "6"}] = event.entitlements
  end

  test "a context or installation type Discord adds later is kept as sent" do
    event =
      EDA.Event.from_raw(
        "INTERACTION_CREATE",
        Map.merge(@payload, %{"context" => 9, "authorizing_integration_owners" => %{"4" => "x"}})
      )

    assert event.context == 9
    assert event.authorizing_integration_owners == %{"4" => "x"}
  end
end
