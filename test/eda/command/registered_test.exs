defmodule EDA.Command.RegisteredTest do
  @moduledoc """
  A registered command reads into the same `EDA.Command` the builders make, and the typed calls
  return it.
  """

  # NOT async — Bypass and the Application env are global.
  use ExUnit.Case

  import EDA.Command
  import EDA.Command.Option

  doctest EDA.Command, only: [from_raw: 1]
  doctest EDA.Command.Option, only: [from_raw: 1]

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

  @registered %{
    "id" => "10",
    "application_id" => "app123",
    "version" => "3",
    "type" => 1,
    "name" => "paint",
    "description" => "Paint something",
    "contexts" => [0],
    "integration_types" => [0, 1],
    "options" => [
      %{
        "type" => 3,
        "name" => "color",
        "description" => "The color",
        "required" => true,
        "choices" => [%{"name" => "Red", "value" => "red"}]
      },
      %{"type" => 7, "name" => "where", "description" => "Where", "channel_types" => [0]}
    ]
  }

  test "a registered command reads into the builder's struct, and sends back the same" do
    cmd = EDA.Command.from_raw(@registered)

    assert %EDA.Command{
             id: "10",
             version: "3",
             type: :slash,
             integration_types: [:guild_install, :user_install]
           } =
             cmd

    assert [%EDA.Command.Option{type: :string, choices: [%{value: "red"}]}, channel] = cmd.options
    assert channel.channel_types == [:guild_text]

    built =
      slash("paint", "Paint something")
      |> contexts([:guild])
      |> integration_types([:guild_install, :user_install])
      |> option(string("color", "The color", required: true, choices: [{"Red", "red"}]))
      |> option(channel("where", "Where", channel_types: [:guild_text]))

    assert Map.delete(EDA.Command.to_map(cmd), :id) == EDA.Command.to_map(built)
    assert EDA.Command.to_map(built).integration_types == [0, 1]
  end

  test "list_global/0 and bulk_overwrite_guild/2 return structs", %{bypass: bypass} do
    Bypass.expect_once(bypass, "GET", "/applications/app123/commands", fn conn ->
      json(conn, [@registered])
    end)

    Bypass.expect_once(bypass, "PUT", "/applications/app123/guilds/1/commands", fn conn ->
      {:ok, raw, conn} = Plug.Conn.read_body(conn)
      assert [%{"type" => 2, "name" => "Info"}] = Jason.decode!(raw)
      json(conn, [%{"id" => "11", "type" => 2, "name" => "Info"}])
    end)

    assert {:ok, [%EDA.Command{name: "paint", type: :slash}]} = EDA.Command.list_global()

    assert {:ok, [%EDA.Command{id: "11", type: :user}]} =
             EDA.Command.bulk_overwrite_guild("1", [user_command("Info")])
  end

  test "permissions/2 returns an EDA.Command.Permissions", %{bypass: bypass} do
    Bypass.expect_once(
      bypass,
      "GET",
      "/applications/app123/guilds/1/commands/10/permissions",
      fn conn ->
        json(conn, %{
          "id" => "10",
          "application_id" => "app123",
          "guild_id" => "1",
          "permissions" => []
        })
      end
    )

    assert {:ok, %EDA.Command.Permissions{id: "10"}} =
             EDA.Command.permissions("1", %EDA.Command{id: "10"})
  end
end
