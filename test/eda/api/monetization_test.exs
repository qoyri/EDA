defmodule EDA.API.MonetizationTest do
  use ExUnit.Case

  alias EDA.API.{Entitlement, SKU, Subscription}

  setup do
    bypass = Bypass.open()
    Application.put_env(:eda, :base_url, "http://localhost:#{bypass.port}")
    Application.put_env(:eda, :token, "test-token")

    # Seed a bot user so app_id() works
    :persistent_term.put(:eda_current_user, %{"id" => "app123"})

    on_exit(fn ->
      Application.delete_env(:eda, :base_url)
    end)

    {:ok, bypass: bypass}
  end

  defp json(conn, body, status \\ 200) do
    conn
    |> Plug.Conn.put_resp_content_type("application/json")
    |> Plug.Conn.resp(status, Jason.encode!(body))
  end

  defp read_json_body(conn) do
    {:ok, raw, conn} = Plug.Conn.read_body(conn)
    {Jason.decode!(raw), conn}
  end

  # ── SKU ──────────────────────────────────────────────────────────────

  describe "SKU.list/0" do
    test "GET /applications/:app_id/skus", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/applications/app123/skus", fn conn ->
        json(conn, [%{"id" => "sku1", "name" => "Premium", "type" => 5}])
      end)

      assert {:ok, [%{"id" => "sku1", "name" => "Premium"}]} = SKU.list()
    end
  end

  # ── Entitlement ──────────────────────────────────────────────────────

  describe "Entitlement.list/1" do
    test "GET /applications/:app_id/entitlements", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/applications/app123/entitlements", fn conn ->
        json(conn, [%{"id" => "ent1", "sku_id" => "sku1", "user_id" => "user1"}])
      end)

      assert {:ok, [%{"id" => "ent1"}]} = Entitlement.list()
    end

    test "passes query params", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/applications/app123/entitlements", fn conn ->
        assert conn.query_string =~ "user_id=user1"
        assert conn.query_string =~ "exclude_ended=true"
        json(conn, [])
      end)

      assert {:ok, []} = Entitlement.list(user_id: "user1", exclude_ended: true)
    end
  end

  describe "Entitlement.get/1" do
    test "GET /applications/:app_id/entitlements/:id", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/applications/app123/entitlements/ent1", fn conn ->
        json(conn, %{"id" => "ent1", "sku_id" => "sku1"})
      end)

      assert {:ok, %{"id" => "ent1"}} = Entitlement.get("ent1")
    end
  end

  describe "Entitlement.consume/1" do
    test "POST /applications/:app_id/entitlements/:id/consume", %{bypass: bypass} do
      Bypass.expect_once(
        bypass,
        "POST",
        "/applications/app123/entitlements/ent1/consume",
        fn conn ->
          Plug.Conn.resp(conn, 204, "")
        end
      )

      assert :ok = Entitlement.consume("ent1")
    end
  end

  describe "Entitlement.create_test/1" do
    test "POST /applications/:app_id/entitlements", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/applications/app123/entitlements", fn conn ->
        {body, conn} = read_json_body(conn)
        assert body["sku_id"] == "sku1"
        assert body["owner_id"] == "user1"
        assert body["owner_type"] == 2
        json(conn, %{"id" => "test_ent", "sku_id" => "sku1"})
      end)

      assert {:ok, %{"id" => "test_ent"}} =
               Entitlement.create_test(%{sku_id: "sku1", owner_id: "user1", owner_type: 2})
    end
  end

  describe "Entitlement.delete_test/1" do
    test "DELETE /applications/:app_id/entitlements/:id", %{bypass: bypass} do
      Bypass.expect_once(bypass, "DELETE", "/applications/app123/entitlements/ent1", fn conn ->
        Plug.Conn.resp(conn, 204, "")
      end)

      assert :ok = Entitlement.delete_test("ent1")
    end
  end

  # ── Subscription ─────────────────────────────────────────────────────

  describe "Subscription.list/2" do
    test "GET /skus/:sku_id/subscriptions", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/skus/sku1/subscriptions", fn conn ->
        assert conn.query_string =~ "user_id=user1"
        json(conn, [%{"id" => "sub1", "user_id" => "user1", "status" => 0}])
      end)

      assert {:ok, [%{"id" => "sub1"}]} = Subscription.list("sku1", user_id: "user1")
    end
  end

  describe "Subscription.get/2" do
    test "GET /skus/:sku_id/subscriptions/:id", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/skus/sku1/subscriptions/sub1", fn conn ->
        json(conn, %{"id" => "sub1", "status" => 0})
      end)

      assert {:ok, %{"id" => "sub1"}} = Subscription.get("sku1", "sub1")
    end
  end
end
