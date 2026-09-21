defmodule EDA.AppTest do
  @moduledoc """
  The bot's own application: `GET` / `PATCH /applications/@me`, the activity instance route,
  and the `EDA.App` struct.

  The fixture is shaped on a real `/applications/@me` response: `integration_types_config` can
  hold a context with no install params at all (`%{"0" => %{}}`), and `flags` and `flags_new`
  carry the same value until a flag above bit 30 exists.
  """

  # NOT async — Bypass and the Application env are global.
  use ExUnit.Case

  import Bitwise

  alias EDA.API.Application, as: AppAPI

  doctest EDA.App

  setup do
    bypass = Bypass.open()
    Application.put_env(:eda, :base_url, "http://localhost:#{bypass.port}")
    Application.put_env(:eda, :token, "test-token")
    on_exit(fn -> Application.delete_env(:eda, :base_url) end)
    {:ok, bypass: bypass}
  end

  defp capture(bypass, method, path, response) do
    test_pid = self()

    Bypass.expect_once(bypass, method, path, fn conn ->
      {:ok, raw, conn} = Plug.Conn.read_body(conn)
      send(test_pid, {:captured, if(raw == "", do: nil, else: Jason.decode!(raw))})

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.resp(200, Jason.encode!(response))
    end)
  end

  @raw %{
    "id" => "897912409065398283",
    "name" => "soraï beta",
    "icon" => "c65fc786594220a830a4e1c187f87ced",
    "description" => "",
    "bot_public" => true,
    "bot_require_code_grant" => false,
    "bot" => %{"id" => "897912409065398283", "username" => "soraï beta", "bot" => true},
    "owner" => %{"id" => "776016158737432626", "username" => "owner"},
    "flags" => 8_953_856,
    "flags_new" => "8953856",
    "approximate_guild_count" => 8,
    "approximate_user_install_count" => 0,
    "install_params" => %{"permissions" => "8", "scopes" => ["bot", "applications.commands"]},
    "integration_types_config" => %{"0" => %{}},
    "redirect_uris" => ["https://example.com/callback"],
    "interactions_endpoint_url" => nil,
    "event_webhooks_status" => 1
  }

  describe "EDA.App.from_raw/1" do
    test "reads a real application object" do
      app = EDA.App.from_raw(@raw)

      assert app.name == "soraï beta"
      assert %EDA.User{id: "776016158737432626"} = app.owner
      assert %EDA.User{bot: true} = app.bot
      assert app.install_params == %{scopes: ["bot", "applications.commands"], permissions: 8}
      assert app.integration_types_config == %{guild_install: nil}
      assert EDA.App.integration_types(app) == [:guild_install]
      assert app.event_webhooks_status == :disabled
    end

    test "flags are named, the limited intents and the command badge here" do
      app = EDA.App.from_raw(@raw)

      assert EDA.App.flags(app) == [
               :gateway_presence_limited,
               :gateway_guild_members_limited,
               :gateway_message_content_limited,
               :application_command_badge
             ]

      assert EDA.App.has_flag?(app, :application_command_badge)
      refute EDA.App.has_flag?(app, :gateway_presence)
    end

    test "flags_new wins: a bit past 30 exists only there" do
      # `flags` stops at 31 bits; a newer flag would only appear in the string.
      raw =
        Map.merge(@raw, %{"flags" => 8192, "flags_new" => Integer.to_string(8192 ||| 1 <<< 40)})

      assert EDA.App.from_raw(raw).flags == (8192 ||| 1 <<< 40)
    end

    test "flags alone still works, for a payload without flags_new" do
      assert EDA.App.from_raw(%{"flags" => 8192}).flags == 8192
    end

    test "both install contexts, keyed by name" do
      raw =
        Map.put(@raw, "integration_types_config", %{
          "0" => %{"oauth2_install_params" => %{"scopes" => ["bot"], "permissions" => "2048"}},
          "1" => %{
            "oauth2_install_params" => %{
              "scopes" => ["applications.commands"],
              "permissions" => "0"
            }
          }
        })

      app = EDA.App.from_raw(raw)
      assert EDA.App.integration_types(app) == [:guild_install, :user_install]
      assert app.integration_types_config.guild_install == %{scopes: ["bot"], permissions: 2048}
    end

    test "icon URL, and nil without an icon" do
      app = EDA.App.from_raw(@raw)

      assert EDA.App.icon_url(app, size: 256) ==
               "https://cdn.discordapp.com/app-icons/897912409065398283/c65fc786594220a830a4e1c187f87ced.png?size=256"

      assert EDA.App.icon_url(%{app | icon: nil}) == nil
    end
  end

  describe "EDA.API.Application" do
    test "me/0 and EDA.App.me/0", %{bypass: bypass} do
      capture(bypass, "GET", "/applications/@me", @raw)
      assert {:ok, %EDA.App{id: "897912409065398283"}} = EDA.App.me()
    end

    test "modify_me/1 translates the friendly forms into Discord's", %{bypass: bypass} do
      capture(bypass, "PATCH", "/applications/@me", @raw)

      assert {:ok, _} =
               AppAPI.modify_me(
                 description: "Moderation",
                 tags: ["moderation", "utility"],
                 flags: [:gateway_message_content_limited, :gateway_presence_limited],
                 install_params: %{scopes: ["bot"], permissions: [:send_messages, :embed_links]},
                 integration_types_config: %{
                   guild_install: %{scopes: ["bot", "applications.commands"], permissions: 8},
                   user_install: %{scopes: ["applications.commands"]}
                 },
                 event_webhooks_status: :enabled
               )

      assert_receive {:captured, body}
      assert body["description"] == "Moderation"
      assert body["flags"] == (1 <<< 19 ||| 1 <<< 13)
      assert body["install_params"] == %{"scopes" => ["bot"], "permissions" => "18432"}

      assert body["integration_types_config"] == %{
               "0" => %{
                 "oauth2_install_params" => %{
                   "scopes" => ["bot", "applications.commands"],
                   "permissions" => "8"
                 }
               },
               "1" => %{"oauth2_install_params" => %{"scopes" => ["applications.commands"]}}
             }

      assert body["event_webhooks_status"] == 2
    end

    test "modify_me/1 turns an icon path into image data", %{bypass: bypass} do
      path =
        Path.join(System.tmp_dir!(), "eda_app_icon_#{System.unique_integer([:positive])}.png")

      File.write!(path, <<0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0, 0>>)
      on_exit(fn -> File.rm(path) end)

      capture(bypass, "PATCH", "/applications/@me", @raw)
      assert {:ok, _} = AppAPI.modify_me(icon: path, cover_image: nil)
      assert_receive {:captured, %{"icon" => "data:image/png;base64," <> _, "cover_image" => nil}}
    end

    test "modify_me/1 refuses what Discord would refuse, before sending" do
      assert_raise ArgumentError, ~r/only the limited intent flags.*gateway_presence/, fn ->
        AppAPI.modify_me(flags: [:gateway_presence])
      end

      assert_raise ArgumentError, ~r/at most 5 tags/, fn ->
        AppAPI.modify_me(tags: ~w(a b c d e f))
      end

      assert_raise ArgumentError, ~r/at most 20 characters/, fn ->
        AppAPI.modify_me(tags: [String.duplicate("x", 21)])
      end

      assert_raise ArgumentError, ~r/unknown app flag/, fn -> AppAPI.modify_me(flags: [:nope]) end

      assert_raise ArgumentError, ~r/:guild_install and :user_install/, fn ->
        AppAPI.modify_me(integration_types_config: %{server: %{}})
      end

      assert_raise ArgumentError, ~r/unknown option \[:name\]/, fn ->
        AppAPI.modify_me(name: "x")
      end
    end

    test "activity_instance/1 is scoped to the bot's application", %{bypass: bypass} do
      previous = :persistent_term.get(:eda_current_user_raw, nil)
      EDA.Cache.put_me(%{"id" => "999", "username" => "eda"})

      on_exit(fn ->
        if previous,
          do: EDA.Cache.put_me(previous),
          else:
            :persistent_term.erase(:eda_current_user) &&
              :persistent_term.erase(:eda_current_user_raw)
      end)

      capture(bypass, "GET", "/applications/999/activity-instances/i-1-gc-2-3", %{
        "instance_id" => "i-1-gc-2-3"
      })

      assert {:ok, %{"instance_id" => "i-1-gc-2-3"}} = AppAPI.activity_instance("i-1-gc-2-3")
    end
  end
end
