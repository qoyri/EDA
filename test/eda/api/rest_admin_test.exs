defmodule EDA.API.RestAdminTest do
  @moduledoc """
  Admin REST routes the 2026-09-21 audit of Discord's reference found missing: voice regions and
  Stage voice states, integrations, welcome screen, preview, vanity URL, widget, incident actions,
  command permissions, and role connection metadata.
  """

  # NOT async — Bypass, the Application env and the cached bot user are global.
  use ExUnit.Case

  doctest EDA.API.Guild, only: [widget_image_url: 2]

  setup do
    bypass = Bypass.open()
    Application.put_env(:eda, :base_url, "http://localhost:#{bypass.port}")
    Application.put_env(:eda, :token, "test-token")
    on_exit(fn -> Application.delete_env(:eda, :base_url) end)
    {:ok, bypass: bypass}
  end

  defp capture(bypass, method, path, response, status \\ 200) do
    test_pid = self()

    Bypass.expect(bypass, method, path, fn conn ->
      {:ok, raw, conn} = Plug.Conn.read_body(conn)
      body = if raw == "", do: nil, else: Jason.decode!(raw)
      send(test_pid, {:captured, body, Plug.Conn.get_req_header(conn, "x-audit-log-reason")})

      if status == 204 do
        Plug.Conn.resp(conn, 204, "")
      else
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(status, Jason.encode!(response))
      end
    end)
  end

  defp with_bot_user(_context) do
    previous = :persistent_term.get(:eda_current_user_raw, nil)
    EDA.Cache.put_me(%{"id" => "999", "username" => "eda"})

    on_exit(fn ->
      if previous,
        do: EDA.Cache.put_me(previous),
        else:
          :persistent_term.erase(:eda_current_user) &&
            :persistent_term.erase(:eda_current_user_raw)
    end)
  end

  describe "EDA.API.Voice" do
    test "regions and a guild's regions", %{bypass: bypass} do
      capture(bypass, "GET", "/voice/regions", [%{"id" => "brazil"}])
      capture(bypass, "GET", "/guilds/1/regions", [%{"id" => "brazil"}])

      assert {:ok, [%{"id" => "brazil"}]} = EDA.API.Voice.regions()
      assert {:ok, [_]} = EDA.API.Guild.voice_regions("1")
    end

    test "voice_state/2 for the bot and for a user", %{bypass: bypass} do
      capture(bypass, "GET", "/guilds/1/voice-states/@me", %{"channel_id" => "5"})
      capture(bypass, "GET", "/guilds/1/voice-states/42", %{"channel_id" => "5"})

      assert {:ok, %{"channel_id" => "5"}} = EDA.API.Voice.voice_state("1", :me)
      assert {:ok, _} = EDA.API.Voice.voice_state("1", "42")
    end

    test "modify_voice_state/3 encodes ids and times, and only the bot can raise its hand",
         %{bypass: bypass} do
      capture(bypass, "PATCH", "/guilds/1/voice-states/@me", nil, 204)

      assert :ok =
               EDA.API.Voice.modify_voice_state("1", :me,
                 channel_id: 5,
                 suppress: false,
                 request_to_speak_timestamp: ~U[2026-09-21 12:00:00Z]
               )

      assert_receive {:captured,
                      %{
                        "channel_id" => "5",
                        "suppress" => false,
                        "request_to_speak_timestamp" => "2026-09-21T12:00:00Z"
                      }, _}

      assert_raise ArgumentError, ~r/unknown option \[:request_to_speak_timestamp\]/, fn ->
        EDA.API.Voice.modify_voice_state("1", "42", request_to_speak_timestamp: nil)
      end
    end
  end

  describe "integrations" do
    test "list, and delete with a reason", %{bypass: bypass} do
      capture(bypass, "GET", "/guilds/1/integrations", [%{"id" => "7", "type" => "discord"}])
      capture(bypass, "DELETE", "/guilds/1/integrations/7", nil, 204)

      assert {:ok, [raw]} = EDA.API.Guild.integrations("1")
      assert EDA.Integration.application?(EDA.Integration.from_raw(raw))
      assert :ok = EDA.API.Guild.delete_integration("1", "7", reason: "cleanup")
      assert_receive {:captured, nil, []}
      assert_receive {:captured, nil, ["cleanup"]}
    end
  end

  describe "welcome screen, preview, vanity URL" do
    test "the reads, and modifying the welcome screen", %{bypass: bypass} do
      capture(bypass, "GET", "/guilds/1/welcome-screen", %{"description" => "hi"})
      capture(bypass, "PATCH", "/guilds/1/welcome-screen", %{"enabled" => true})
      capture(bypass, "GET", "/guilds/1/preview", %{"id" => "1"})
      capture(bypass, "GET", "/guilds/1/vanity-url", %{"code" => "eda", "uses" => 12})

      assert {:ok, %{"description" => "hi"}} = EDA.API.Guild.welcome_screen("1")

      assert {:ok, _} =
               EDA.API.Guild.modify_welcome_screen("1",
                 enabled: true,
                 welcome_channels: [%{channel_id: "2", description: "Rules", emoji_name: "📜"}],
                 reason: "onboard"
               )

      assert_receive {:captured, nil, _}
      assert_receive {:captured, %{"enabled" => true, "welcome_channels" => [_]}, ["onboard"]}

      assert {:ok, %{"id" => "1"}} = EDA.API.Guild.preview("1")
      assert {:ok, %{"uses" => 12}} = EDA.API.Guild.vanity_url("1")
    end
  end

  describe "widget" do
    test "settings, their modification, and the public widget", %{bypass: bypass} do
      capture(bypass, "GET", "/guilds/1/widget", %{"enabled" => false, "channel_id" => nil})
      capture(bypass, "PATCH", "/guilds/1/widget", %{"enabled" => true, "channel_id" => "2"})
      capture(bypass, "GET", "/guilds/1/widget.json", %{"id" => "1", "presence_count" => 3})

      assert {:ok, %{"enabled" => false}} = EDA.API.Guild.widget_settings("1")
      assert {:ok, _} = EDA.API.Guild.modify_widget("1", enabled: true, channel_id: "2")
      assert_receive {:captured, nil, _}
      assert_receive {:captured, %{"enabled" => true, "channel_id" => "2"}, []}
      assert {:ok, %{"presence_count" => 3}} = EDA.API.Guild.widget("1")
    end

    test "widget_image_url/2 refuses a style Discord does not offer" do
      assert_raise FunctionClauseError, fn -> EDA.API.Guild.widget_image_url("1", :banner9) end
    end
  end

  describe "incident actions" do
    test "a DateTime within 24 hours, or nil to lift the pause", %{bypass: bypass} do
      capture(bypass, "PUT", "/guilds/1/incident-actions", %{})
      until = DateTime.add(DateTime.utc_now(), 3600) |> DateTime.truncate(:second)

      assert {:ok, _} =
               EDA.API.Guild.modify_incident_actions("1",
                 invites_disabled_until: until,
                 dms_disabled_until: nil
               )

      expected = DateTime.to_iso8601(until)

      assert_receive {:captured,
                      %{"invites_disabled_until" => ^expected, "dms_disabled_until" => nil}, _}
    end

    test "more than 24 hours ahead is refused before sending" do
      assert_raise ArgumentError, ~r/at most 24 hours/, fn ->
        EDA.API.Guild.modify_incident_actions("1",
          invites_disabled_until: DateTime.add(DateTime.utc_now(), 25 * 3600)
        )
      end
    end
  end

  describe "command permissions" do
    setup :with_bot_user

    test "for every command and for one", %{bypass: bypass} do
      capture(bypass, "GET", "/applications/999/guilds/1/commands/permissions", [])

      capture(bypass, "GET", "/applications/999/guilds/1/commands/5/permissions", %{
        "id" => "5",
        "application_id" => "999",
        "guild_id" => "1",
        "permissions" => [%{"id" => "1", "type" => 1, "permission" => false}]
      })

      assert {:ok, []} = EDA.API.Command.permissions("1")
      assert {:ok, raw} = EDA.API.Command.permissions("1", "5")

      assert [%{type: :role, permission: false}] =
               EDA.Command.Permissions.from_raw(raw).permissions
    end
  end

  describe "role connection metadata" do
    setup :with_bot_user

    test "read, and replace with named types", %{bypass: bypass} do
      capture(bypass, "GET", "/applications/999/role-connections/metadata", [])
      capture(bypass, "PUT", "/applications/999/role-connections/metadata", [])

      assert {:ok, []} = EDA.API.Application.role_connection_metadata()

      assert {:ok, _} =
               EDA.API.Application.update_role_connection_metadata([
                 %{
                   type: :integer_greater_than_or_equal,
                   key: "level",
                   name: "Level",
                   description: "Minimum level"
                 }
               ])

      assert_receive {:captured, nil, _}
      assert_receive {:captured, [%{"type" => 2, "key" => "level"}], _}
    end

    test "refuses what Discord would refuse" do
      record = %{type: :boolean_equal, key: "ok", name: "N", description: "D"}

      assert_raise ArgumentError, ~r/at most 5/, fn ->
        EDA.API.Application.update_role_connection_metadata(List.duplicate(record, 6))
      end

      assert_raise ArgumentError, ~r/a-z, 0-9 and _/, fn ->
        EDA.API.Application.update_role_connection_metadata([%{record | key: "Has Space"}])
      end

      assert_raise ArgumentError, ~r/unknown role connection metadata type/, fn ->
        EDA.API.Application.update_role_connection_metadata([%{record | type: :fuzzy}])
      end
    end
  end
end
