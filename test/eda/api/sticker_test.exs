defmodule EDA.API.StickerTest do
  use ExUnit.Case

  # The API layer returns Discord's maps; these tests go through the entity, which parses them.
  alias EDA.Sticker

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

  # ── list_guild_stickers ────────────────────────────────────────────

  describe "list/1" do
    test "GET /guilds/:id/stickers returns Sticker structs", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/guilds/111/stickers", fn conn ->
        json(conn, [
          %{"id" => "s1", "name" => "wave", "type" => 2, "format_type" => 1}
        ])
      end)

      assert {:ok, [%EDA.Sticker{id: "s1", type: :guild, format_type: :png}]} =
               Sticker.list("111")
    end
  end

  # ── get_guild_sticker ──────────────────────────────────────────────

  describe "get_guild/2" do
    test "GET /guilds/:id/stickers/:sid returns Sticker struct", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/guilds/111/stickers/s1", fn conn ->
        json(conn, %{"id" => "s1", "name" => "wave", "type" => 2, "format_type" => 1})
      end)

      assert {:ok, %EDA.Sticker{id: "s1", name: "wave"}} =
               Sticker.fetch_sticker("111", "s1")
    end
  end

  # ── create_guild_sticker ───────────────────────────────────────────

  describe "create/2" do
    test "POST /guilds/:id/stickers sends multipart and returns Sticker struct", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/guilds/111/stickers", fn conn ->
        [content_type] = Plug.Conn.get_req_header(conn, "content-type")
        assert content_type =~ "multipart/form-data"
        json(conn, %{"id" => "s2", "name" => "new", "type" => 2, "format_type" => 1})
      end)

      file = EDA.File.from_binary("png_data", "sticker.png")

      assert {:ok, %EDA.Sticker{id: "s2", name: "new"}} =
               Sticker.create("111", %{
                 name: "new",
                 description: "A new sticker",
                 tags: "wave",
                 file: file
               })
    end
  end

  # ── modify_guild_sticker ───────────────────────────────────────────

  describe "modify/3" do
    test "PATCH /guilds/:id/stickers/:sid returns Sticker struct", %{bypass: bypass} do
      Bypass.expect_once(bypass, "PATCH", "/guilds/111/stickers/s1", fn conn ->
        {body, conn} = read_json_body(conn)
        assert body["name"] == "updated"
        json(conn, %{"id" => "s1", "name" => "updated", "type" => 2, "format_type" => 1})
      end)

      assert {:ok, %EDA.Sticker{name: "updated"}} =
               Sticker.modify("111", "s1", %{name: "updated"})
    end
  end

  # ── delete_guild_sticker ───────────────────────────────────────────

  describe "delete_guild/2" do
    test "DELETE /guilds/:id/stickers/:sid", %{bypass: bypass} do
      Bypass.expect_once(bypass, "DELETE", "/guilds/111/stickers/s1", fn conn ->
        Plug.Conn.resp(conn, 204, "")
      end)

      assert :ok = Sticker.delete("111", "s1")
    end
  end

  # ── get_sticker ────────────────────────────────────────────────────

  describe "get/1" do
    test "GET /stickers/:id returns Sticker struct", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/stickers/s1", fn conn ->
        json(conn, %{"id" => "s1", "name" => "wave", "type" => 1, "format_type" => 3})
      end)

      assert {:ok, %EDA.Sticker{id: "s1", type: :standard, format_type: :lottie}} =
               Sticker.fetch("s1")
    end
  end

  # ── list_sticker_packs ─────────────────────────────────────────────

  describe "list_packs/0" do
    test "GET /sticker-packs returns Pack structs", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/sticker-packs", fn conn ->
        json(conn, %{
          "sticker_packs" => [
            %{
              "id" => "p1",
              "name" => "Wumpus",
              "sku_id" => "sku1",
              "stickers" => [%{"id" => "s1", "name" => "wave", "type" => 1, "format_type" => 1}]
            }
          ]
        })
      end)

      assert {:ok, [%EDA.Sticker.Pack{id: "p1", name: "Wumpus"}]} = Sticker.list_packs()
    end
  end

  # ── get_sticker_pack ───────────────────────────────────────────────

  describe "get_pack/1" do
    test "GET /sticker-packs/:id returns Pack struct", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/sticker-packs/p1", fn conn ->
        json(conn, %{
          "id" => "p1",
          "name" => "Wumpus",
          "stickers" => [%{"id" => "s1", "name" => "wave", "type" => 1, "format_type" => 1}]
        })
      end)

      assert {:ok, %EDA.Sticker.Pack{id: "p1"}} = Sticker.fetch_pack("p1")
    end
  end
end
