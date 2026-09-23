defmodule EDA.TypedEntitiesTest do
  @moduledoc """
  Webhooks, scheduled events, stages, entitlements and soundboard sounds have typed calls that
  return their structs, where `EDA.API` returns Discord's maps.
  """

  # NOT async — Bypass and the Application env are global.
  use ExUnit.Case

  setup do
    bypass = Bypass.open()
    Application.put_env(:eda, :base_url, "http://localhost:#{bypass.port}")
    Application.put_env(:eda, :token, "test-token")

    previous = :persistent_term.get(:eda_current_user_raw, nil)
    EDA.Cache.put_me(%{"id" => "app123"})

    on_exit(fn ->
      Application.delete_env(:eda, :base_url)

      if previous,
        do: EDA.Cache.put_me(previous),
        else:
          :persistent_term.erase(:eda_current_user) &&
            :persistent_term.erase(:eda_current_user_raw)
    end)

    {:ok, bypass: bypass}
  end

  defp json(conn, body) do
    conn
    |> Plug.Conn.put_resp_content_type("application/json")
    |> Plug.Conn.resp(200, Jason.encode!(body))
  end

  test "a webhook is created, sends a message it can then fetch, and is deleted",
       %{bypass: bypass} do
    Bypass.expect_once(bypass, "POST", "/channels/10/webhooks", fn conn ->
      json(conn, %{"id" => "7", "token" => "tok", "type" => 1, "channel_id" => "10"})
    end)

    Bypass.expect_once(bypass, "POST", "/webhooks/7/tok", fn conn ->
      assert Plug.Conn.fetch_query_params(conn).query_params["wait"] == "true"
      json(conn, %{"id" => "70", "content" => "hi", "webhook_id" => "7"})
    end)

    Bypass.expect_once(bypass, "GET", "/webhooks/7/tok/messages/70", fn conn ->
      json(conn, %{"id" => "70", "content" => "hi"})
    end)

    Bypass.expect_once(bypass, "DELETE", "/webhooks/7", fn conn ->
      Plug.Conn.resp(conn, 204, "")
    end)

    assert {:ok, %EDA.Webhook{id: "7", type: :incoming} = hook} =
             EDA.Webhook.create(%EDA.Channel{id: "10"}, name: "hook")

    assert {:ok, %EDA.Message{id: "70", webhook_id: "7"} = sent} =
             EDA.Webhook.execute(hook, content: "hi", wait: true)

    assert {:ok, %EDA.Message{content: "hi"}} = EDA.Webhook.fetch_message(hook, sent)
    assert :ok = EDA.Webhook.delete(hook)
  end

  test "a scheduled event's subscribers, with their member", %{bypass: bypass} do
    Bypass.expect_once(bypass, "GET", "/guilds/1/scheduled-events", fn conn ->
      json(conn, [%{"id" => "5", "guild_id" => "1", "name" => "Launch", "status" => 1}])
    end)

    Bypass.expect_once(bypass, "GET", "/guilds/1/scheduled-events/5/users", fn conn ->
      json(conn, [
        %{
          "guild_scheduled_event_id" => "5",
          "user" => %{"id" => "9", "username" => "ann"},
          "member" => %{"nick" => "Annie", "roles" => []}
        }
      ])
    end)

    assert {:ok, [%EDA.ScheduledEvent{status: :scheduled} = event]} = EDA.ScheduledEvent.list("1")

    assert {:ok,
            [%EDA.ScheduledEvent.Subscriber{user: %EDA.User{username: "ann"}, member: member}]} =
             EDA.ScheduledEvent.subscribers(event, with_member: true)

    assert member.nick == "Annie"
  end

  test "stages, entitlements and soundboard sounds", %{bypass: bypass} do
    Bypass.expect_once(bypass, "POST", "/stage-instances", fn conn ->
      json(conn, %{"id" => "3", "channel_id" => "4", "topic" => "Q&A", "privacy_level" => 2})
    end)

    Bypass.expect_once(bypass, "GET", "/applications/app123/entitlements", fn conn ->
      json(conn, [%{"id" => "6", "sku_id" => "2", "type" => 8}])
    end)

    Bypass.expect_once(bypass, "POST", "/applications/app123/entitlements/6/consume", fn conn ->
      Plug.Conn.resp(conn, 204, "")
    end)

    Bypass.expect_once(bypass, "PATCH", "/guilds/1/soundboard-sounds/8", fn conn ->
      json(conn, %{"sound_id" => "8", "name" => "quack", "guild_id" => "1"})
    end)

    assert {:ok, %EDA.StageInstance{topic: "Q&A", privacy_level: :guild_only}} =
             EDA.StageInstance.create(%{channel_id: "4", topic: "Q&A"})

    assert {:ok, [%EDA.Entitlement{id: "6"} = entitlement]} = EDA.Entitlement.list()
    assert :ok = EDA.Entitlement.consume(entitlement)

    assert {:ok, %EDA.SoundboardSound{name: "quack"}} =
             EDA.SoundboardSound.modify("1", %EDA.SoundboardSound{sound_id: "8"}, name: "quack")
  end
end
