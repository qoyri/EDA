defmodule EDA.TypedGuildCallsTest do
  @moduledoc """
  Channels and threads, members, bans, invites, a guild's integrations and welcome screen, role
  positions, the bot user and voice states have typed calls returning their structs.
  """

  # NOT async — Bypass and the Application env are global.
  use ExUnit.Case

  setup do
    bypass = Bypass.open()
    Application.put_env(:eda, :base_url, "http://localhost:#{bypass.port}")
    Application.put_env(:eda, :token, "test-token")
    on_exit(fn -> Application.delete_env(:eda, :base_url) end)
    {:ok, bypass: bypass}
  end

  defp json(conn, body) do
    conn
    |> Plug.Conn.put_resp_content_type("application/json")
    |> Plug.Conn.resp(200, Jason.encode!(body))
  end

  test "a thread started from a message, its members, and a guild's active threads",
       %{bypass: bypass} do
    Bypass.expect_once(bypass, "POST", "/channels/10/messages/20/threads", fn conn ->
      json(conn, %{"id" => "30", "type" => 11, "name" => "talk", "parent_id" => "10"})
    end)

    Bypass.expect_once(bypass, "GET", "/channels/30/thread-members", fn conn ->
      json(conn, [
        %{"id" => "30", "user_id" => "5", "join_timestamp" => "2026-09-23T10:00:00+00:00"}
      ])
    end)

    Bypass.expect_once(bypass, "GET", "/guilds/1/threads/active", fn conn ->
      json(conn, %{"threads" => [%{"id" => "30", "type" => 11}], "members" => [%{"id" => "30"}]})
    end)

    assert {:ok, %EDA.Channel{id: "30", type: :public_thread} = thread} =
             EDA.Channel.start_thread(%EDA.Message{channel_id: "10", id: "20"}, name: "talk")

    assert {:ok, [%EDA.Channel.ThreadMember{user_id: "5", join_timestamp: %DateTime{}}]} =
             EDA.Channel.thread_members(thread)

    assert {:ok, %{threads: [%EDA.Channel{}], members: [%EDA.Channel.ThreadMember{}]}} =
             EDA.Channel.active_threads("1")
  end

  test "members listed and searched carry their guild", %{bypass: bypass} do
    Bypass.expect_once(bypass, "GET", "/guilds/1/members/search", fn conn ->
      json(conn, [%{"user" => %{"id" => "5", "username" => "ann"}, "roles" => []}])
    end)

    assert {:ok, [%EDA.Member{guild_id: "1", user: %EDA.User{username: "ann"}}]} =
             EDA.Member.search("1", "an")
  end

  test "bans: list, one, and a bulk ban", %{bypass: bypass} do
    Bypass.expect_once(bypass, "GET", "/guilds/1/bans", fn conn ->
      json(conn, [%{"user" => %{"id" => "5"}, "reason" => "spam"}])
    end)

    Bypass.expect_once(bypass, "GET", "/guilds/1/bans/5", fn conn ->
      json(conn, %{"user" => %{"id" => "5"}, "reason" => "spam"})
    end)

    Bypass.expect_once(bypass, "POST", "/guilds/1/bulk-ban", fn conn ->
      json(conn, %{"banned_users" => ["5"], "failed_users" => ["6"]})
    end)

    assert {:ok, [%EDA.Ban{guild_id: "1", reason: "spam", user: %EDA.User{id: "5"}}]} =
             EDA.Ban.list("1")

    assert {:ok, %EDA.Ban{reason: "spam"}} = EDA.Ban.fetch_ban("1", %EDA.User{id: "5"})

    assert {:ok, %{banned_users: ["5"], failed_users: ["6"]}} =
             EDA.Ban.bulk("1", ["5", %EDA.User{id: "6"}])
  end

  test "a guild's invites, integrations and welcome screen", %{bypass: bypass} do
    Bypass.expect_once(bypass, "GET", "/guilds/1/invites", fn conn ->
      json(conn, [%{"code" => "abc", "guild" => %{"id" => "1"}}])
    end)

    Bypass.expect_once(bypass, "GET", "/guilds/1/integrations", fn conn ->
      json(conn, [%{"id" => "8", "type" => "discord", "name" => "Bot"}])
    end)

    Bypass.expect_once(bypass, "GET", "/guilds/1/welcome-screen", fn conn ->
      json(conn, %{"description" => "Hi", "welcome_channels" => []})
    end)

    assert {:ok, [%EDA.Invite{code: "abc", guild_id: "1"}]} = EDA.Invite.list_guild("1")
    assert {:ok, [%EDA.Integration{name: "Bot", guild_id: "1"}]} = EDA.Guild.integrations("1")

    assert {:ok, %EDA.Guild.WelcomeScreen{description: "Hi"}} =
             EDA.Guild.welcome_screen(%EDA.Guild{id: "1"})
  end

  test "role positions, the bot user and a voice state", %{bypass: bypass} do
    Bypass.expect_once(bypass, "PATCH", "/guilds/1/roles", fn conn ->
      json(conn, [%{"id" => "2", "position" => 1}])
    end)

    Bypass.expect_once(bypass, "GET", "/users/@me", fn conn ->
      json(conn, %{"id" => "99", "username" => "bot", "bot" => true})
    end)

    Bypass.expect_once(bypass, "GET", "/guilds/1/voice-states/5", fn conn ->
      json(conn, %{"user_id" => "5", "channel_id" => "7", "self_mute" => true})
    end)

    assert {:ok, [%EDA.Role{id: "2", guild_id: "1"}]} =
             EDA.Role.modify_positions("1", [%{id: "2", position: 1}])

    assert {:ok, %EDA.User{id: "99", bot: true}} = EDA.User.me()

    assert {:ok, %EDA.VoiceState{guild_id: "1", channel_id: "7", self_mute: true}} =
             EDA.VoiceState.fetch_state("1", "5")
  end
end
