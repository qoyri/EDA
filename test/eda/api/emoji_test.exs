defmodule EDA.API.EmojiTest do
  use ExUnit.Case

  # The API layer returns Discord's maps; these tests go through the entity, which parses them.
  alias EDA.Emoji

  setup do
    bypass = Bypass.open()
    Application.put_env(:eda, :base_url, "http://localhost:#{bypass.port}")
    Application.put_env(:eda, :token, "test-token")

    on_exit(fn ->
      Application.delete_env(:eda, :base_url)
    end)

    {:ok, bypass: bypass}
  end

  # ── Helpers ──────────────────────────────────────────────────────────

  defp json(conn, body, status \\ 200) do
    conn
    |> Plug.Conn.put_resp_content_type("application/json")
    |> Plug.Conn.resp(status, Jason.encode!(body))
  end

  defp read_json_body(conn) do
    {:ok, raw, conn} = Plug.Conn.read_body(conn)
    {Jason.decode!(raw), conn}
  end

  # ── list_guild_emojis ──────────────────────────────────────────────

  describe "list/1" do
    test "GET /guilds/:id/emojis returns Emoji structs", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/guilds/111/emojis", fn conn ->
        json(conn, [
          %{"id" => "e1", "name" => "cool", "animated" => false},
          %{"id" => nil, "name" => "\u{1F44D}"}
        ])
      end)

      assert {:ok, emojis} = Emoji.list("111")
      assert [%EDA.Emoji{id: "e1", name: "cool"}, %EDA.Emoji{id: nil, name: "\u{1F44D}"}] = emojis
    end
  end

  # ── get_guild_emoji ────────────────────────────────────────────────

  describe "get/2" do
    test "GET /guilds/:id/emojis/:eid returns Emoji struct", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/guilds/111/emojis/e1", fn conn ->
        json(conn, %{"id" => "e1", "name" => "cool", "animated" => true})
      end)

      assert {:ok, %EDA.Emoji{id: "e1", animated: true}} = Emoji.fetch_emoji("111", "e1")
    end
  end

  # ── create_guild_emoji ─────────────────────────────────────────────

  describe "create/2" do
    test "POST /guilds/:id/emojis returns Emoji struct", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/guilds/111/emojis", fn conn ->
        {body, conn} = read_json_body(conn)
        assert body["name"] == "newemoji"
        assert body["image"] =~ "data:image/png"
        json(conn, %{"id" => "e2", "name" => "newemoji"})
      end)

      assert {:ok, %EDA.Emoji{id: "e2", name: "newemoji"}} =
               Emoji.create("111", %{
                 name: "newemoji",
                 image: "data:image/png;base64,abc"
               })
    end
  end

  # ── modify_guild_emoji ─────────────────────────────────────────────

  describe "modify/3" do
    test "PATCH /guilds/:id/emojis/:eid returns Emoji struct", %{bypass: bypass} do
      Bypass.expect_once(bypass, "PATCH", "/guilds/111/emojis/e1", fn conn ->
        {body, conn} = read_json_body(conn)
        assert body["name"] == "renamed"
        json(conn, %{"id" => "e1", "name" => "renamed"})
      end)

      assert {:ok, %EDA.Emoji{name: "renamed"}} =
               Emoji.modify("111", "e1", %{name: "renamed"})
    end
  end

  # ── delete_guild_emoji ─────────────────────────────────────────────

  describe "delete/2" do
    test "DELETE /guilds/:id/emojis/:eid", %{bypass: bypass} do
      Bypass.expect_once(bypass, "DELETE", "/guilds/111/emojis/e1", fn conn ->
        Plug.Conn.resp(conn, 204, "")
      end)

      assert :ok = Emoji.delete("111", "e1")
    end
  end
end
