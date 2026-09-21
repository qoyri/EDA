defmodule EDA.SoraiFeedbackTest do
  @moduledoc """
  Issues reported by a bot running EDA in production, checked against `next` and fixed:
  interaction callbacks losing their attachment metadata, REST members never cached, and three
  helpers the bot had to write for itself.
  """

  # NOT async — Bypass, the Application env and the caches are global.
  use ExUnit.Case

  doctest EDA.Error, only: [not_found?: 1]

  setup do
    bypass = Bypass.open()
    Application.put_env(:eda, :base_url, "http://localhost:#{bypass.port}")
    Application.put_env(:eda, :token, "test-token")
    on_exit(fn -> Application.delete_env(:eda, :base_url) end)
    {:ok, bypass: bypass}
  end

  describe "interaction callback attachments" do
    test "go inside data, where Discord reads them", %{bypass: bypass} do
      test_pid = self()

      Bypass.expect_once(bypass, "POST", "/interactions/1/tok/callback", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        send(test_pid, {:body, body})
        Plug.Conn.resp(conn, 204, "")
      end)

      file = EDA.File.from_binary("hi", "note.txt", description: "A note", spoiler: true)

      assert :ok =
               EDA.Interaction.respond(%{"id" => "1", "token" => "tok"},
                 content: "here",
                 files: [file]
               )

      assert_receive {:body, body}
      [_, json | _] = String.split(body, "\r\n\r\n", parts: 3)
      payload = json |> String.split("\r\n--") |> hd() |> Jason.decode!()

      assert payload["type"] == 4
      refute Map.has_key?(payload, "attachments")

      assert [
               %{
                 "id" => 0,
                 "filename" => "note.txt",
                 "description" => "A note",
                 "is_spoiler" => true
               }
             ] =
               payload["data"]["attachments"]

      assert payload["data"]["content"] == "here"
    end

    test "attachments already in data are kept, uploads appended" do
      {body, _} =
        EDA.HTTP.Multipart.encode(
          %{type: 7, data: %{content: "x", attachments: [%{id: "900"}]}},
          [EDA.File.from_binary("a", "a.txt")],
          attachments_in: :data
        )

      json = body |> IO.iodata_to_binary() |> String.split("\r\n\r\n", parts: 3) |> Enum.at(1)
      payload = json |> String.split("\r\n--") |> hd() |> Jason.decode!()

      assert [%{"id" => "900"}, %{"id" => 0, "filename" => "a.txt"}] =
               payload["data"]["attachments"]
    end

    test "a message payload keeps its attachments at the top level" do
      {body, _} = EDA.HTTP.Multipart.encode(%{content: "x"}, [EDA.File.from_binary("a", "a.txt")])
      json = body |> IO.iodata_to_binary() |> String.split("\r\n\r\n", parts: 3) |> Enum.at(1)
      assert %{"attachments" => [_]} = json |> String.split("\r\n--") |> hd() |> Jason.decode!()
    end
  end

  describe "Cache.fetch_member/2" do
    test "caches the member it fetched over REST, under the guild asked for", %{bypass: bypass} do
      guild_id = "8800000000000000001"
      user_id = "8800000000000000002"

      Bypass.expect_once(bypass, "GET", "/guilds/#{guild_id}/members/#{user_id}", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{"user" => %{"id" => user_id, "username" => "ada"}, "roles" => []})
        )
      end)

      assert {:ok, %{"user" => %{"id" => ^user_id}}} = EDA.Cache.fetch_member(guild_id, user_id)
      # The second call is served from the cache: Bypass would fail on an unexpected request.
      assert {:ok, %{"guild_id" => ^guild_id}} = EDA.Cache.fetch_member(guild_id, user_id)
    end
  end

  describe "roles" do
    setup do
      guild_id = "8800000000000000010"

      for {id, position} <- [
            {"8800000000000000011", 3},
            {"8800000000000000012", 7},
            {"8800000000000000013", 7}
          ] do
        EDA.Cache.Role.create(guild_id, %{
          "id" => id,
          "name" => "r#{position}",
          "position" => position
        })
      end

      {:ok, guild_id: guild_id}
    end

    test "Cache.get_role/2 looks up by guild and role, and not across guilds", %{guild_id: g} do
      assert %{"position" => 3} = EDA.Cache.get_role(g, "8800000000000000011")
      assert EDA.Cache.get_role("8800000000000000999", "8800000000000000011") == nil
    end

    test "Member.top_role/2 takes the highest position, the lower id on a tie", %{guild_id: g} do
      member = %EDA.Member{
        roles: ["8800000000000000011", "8800000000000000013", "8800000000000000012"]
      }

      assert %{"id" => "8800000000000000012"} = EDA.Member.top_role(member, g)
      assert EDA.Member.top_role_position(member, g) == 7
      assert EDA.Member.top_role_position(%{"roles" => []}, g) == 0
    end
  end
end
