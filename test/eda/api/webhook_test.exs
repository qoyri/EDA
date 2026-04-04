defmodule EDA.API.WebhookTest do
  use ExUnit.Case

  alias EDA.API.Webhook

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

  # ── create_webhook ─────────────────────────────────────────────────

  describe "create/2" do
    test "POST /channels/:id/webhooks", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/channels/111/webhooks", fn conn ->
        {body, conn} = read_json_body(conn)
        assert body["name"] == "my-hook"
        json(conn, %{"id" => "555", "name" => "my-hook"})
      end)

      assert {:ok, %{"name" => "my-hook"}} =
               Webhook.create("111", %{name: "my-hook"})
    end
  end

  # ── get_channel_webhooks ───────────────────────────────────────────

  describe "list_channel/1" do
    test "GET /channels/:id/webhooks", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/channels/111/webhooks", fn conn ->
        json(conn, [%{"id" => "555"}])
      end)

      assert {:ok, [%{"id" => "555"}]} = Webhook.list_channel("111")
    end
  end

  # ── get_guild_webhooks ─────────────────────────────────────────────

  describe "list_guild/1" do
    test "GET /guilds/:id/webhooks", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/guilds/111/webhooks", fn conn ->
        json(conn, [%{"id" => "555"}])
      end)

      assert {:ok, [%{"id" => "555"}]} = Webhook.list_guild("111")
    end
  end

  # ── get_webhook ────────────────────────────────────────────────────

  describe "get/1" do
    test "GET /webhooks/:id", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/webhooks/555", fn conn ->
        json(conn, %{"id" => "555", "name" => "hook"})
      end)

      assert {:ok, %{"name" => "hook"}} = Webhook.get("555")
    end
  end

  # ── modify_webhook ─────────────────────────────────────────────────

  describe "modify/2" do
    test "PATCH /webhooks/:id", %{bypass: bypass} do
      Bypass.expect_once(bypass, "PATCH", "/webhooks/555", fn conn ->
        {body, conn} = read_json_body(conn)
        assert body["name"] == "renamed"
        json(conn, %{"id" => "555", "name" => "renamed"})
      end)

      assert {:ok, %{"name" => "renamed"}} =
               Webhook.modify("555", %{name: "renamed"})
    end
  end

  # ── delete_webhook ─────────────────────────────────────────────────

  describe "delete/1" do
    test "DELETE /webhooks/:id", %{bypass: bypass} do
      Bypass.expect_once(bypass, "DELETE", "/webhooks/555", fn conn ->
        Plug.Conn.resp(conn, 204, "")
      end)

      assert :ok = Webhook.delete("555")
    end
  end

  # ── execute_webhook ────────────────────────────────────────────────

  describe "execute/3" do
    test "POST /webhooks/:id/:token", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/webhooks/555/tok-123", fn conn ->
        {body, conn} = read_json_body(conn)
        assert body["content"] == "webhook msg"
        json(conn, %{"id" => "1"})
      end)

      assert {:ok, _} = Webhook.execute("555", "tok-123", %{content: "webhook msg"})
    end
  end

  # ── get_message ──────────────────────────────────────────────────────

  describe "get_message/3" do
    test "GET /webhooks/:id/:token/messages/:msg_id", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/webhooks/555/tok-123/messages/999", fn conn ->
        json(conn, %{"id" => "999", "content" => "hello"})
      end)

      assert {:ok, %{"id" => "999", "content" => "hello"}} =
               Webhook.get_message("555", "tok-123", "999")
    end
  end

  # ── edit_message ─────────────────────────────────────────────────────

  describe "edit_message/4" do
    test "PATCH /webhooks/:id/:token/messages/:msg_id with map", %{bypass: bypass} do
      Bypass.expect_once(bypass, "PATCH", "/webhooks/555/tok-123/messages/999", fn conn ->
        {body, conn} = read_json_body(conn)
        assert body["content"] == "edited"
        json(conn, %{"id" => "999", "content" => "edited"})
      end)

      assert {:ok, %{"content" => "edited"}} =
               Webhook.edit_message("555", "tok-123", "999", %{content: "edited"})
    end

    test "PATCH /webhooks/:id/:token/messages/:msg_id with keyword", %{bypass: bypass} do
      Bypass.expect_once(bypass, "PATCH", "/webhooks/555/tok-123/messages/999", fn conn ->
        {body, conn} = read_json_body(conn)
        assert body["content"] == "keyword edit"
        json(conn, %{"id" => "999", "content" => "keyword edit"})
      end)

      assert {:ok, %{"content" => "keyword edit"}} =
               Webhook.edit_message("555", "tok-123", "999", content: "keyword edit")
    end
  end

  # ── delete_message ───────────────────────────────────────────────────

  describe "delete_message/3" do
    test "DELETE /webhooks/:id/:token/messages/:msg_id", %{bypass: bypass} do
      Bypass.expect_once(bypass, "DELETE", "/webhooks/555/tok-123/messages/999", fn conn ->
        Plug.Conn.resp(conn, 204, "")
      end)

      assert :ok = Webhook.delete_message("555", "tok-123", "999")
    end
  end
end
