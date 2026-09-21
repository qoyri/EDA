defmodule EDA.API.SubscriptionTest do
  @moduledoc """
  Covers the subscription listing endpoint's options.

  `user_id` is the filter that decides *whose* subscriptions come back, so a misspelt key is
  not a cosmetic mistake: Discord ignores what it does not recognise and answers with every
  subscription to the SKU instead of one person's.
  """

  # NOT async — Bypass and the Application env are global.
  use ExUnit.Case

  alias EDA.API.Subscription

  setup do
    bypass = Bypass.open()
    Application.put_env(:eda, :base_url, "http://localhost:#{bypass.port}")
    Application.put_env(:eda, :token, "test-token")

    on_exit(fn -> Application.delete_env(:eda, :base_url) end)

    {:ok, bypass: bypass}
  end

  describe "list/2" do
    test "sends the documented filters", %{bypass: bypass} do
      test_pid = self()

      Bypass.expect_once(bypass, "GET", "/skus/sku1/subscriptions", fn conn ->
        send(test_pid, {:query, conn.query_string})

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!([%{"id" => "s1", "status" => 0}]))
      end)

      assert {:ok, [%{"id" => "s1"}]} = Subscription.list("sku1", user_id: "u1", limit: 10)

      assert_receive {:query, query}
      assert URI.decode_query(query) == %{"user_id" => "u1", "limit" => "10"}
    end

    test "a misspelt user_id is refused rather than widening the query", %{bypass: bypass} do
      Bypass.down(bypass)

      error = assert_raise(ArgumentError, fn -> Subscription.list("sku1", user: "u1") end)

      assert error.message =~ "unknown option [:user]"
      assert error.message =~ ":user_id"
    end

    test "several unknown keys are reported together", %{bypass: bypass} do
      Bypass.down(bypass)

      assert_raise ArgumentError, ~r/unknown options \[:foo, :bar\]/, fn ->
        Subscription.list("sku1", foo: 1, bar: 2)
      end
    end

    test "every documented option is accepted", %{bypass: bypass} do
      Bypass.down(bypass)

      assert {:error, _} =
               Subscription.list("sku1", user_id: "u1", before: "1", after: "2", limit: 50)
    end

    test "no options is a bare path", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/skus/sku1/subscriptions", fn conn ->
        assert conn.query_string == ""

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!([]))
      end)

      assert {:ok, []} = Subscription.list("sku1")
    end
  end

  describe "EDA.Subscription.list/2" do
    test "parses the page into structs", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/skus/sku1/subscriptions", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!([
            %{"id" => "s1", "status" => 0, "user_id" => "u1"},
            %{"id" => "s2", "status" => 2, "user_id" => "u2"}
          ])
        )
      end)

      assert {:ok, [first, second]} = EDA.Subscription.list("sku1", user_id: "u1")

      assert %EDA.Subscription{id: "s1"} = first
      assert EDA.Subscription.status(first) == :active
      assert EDA.Subscription.renewing?(first)
      assert EDA.Subscription.status(second) == :ending
      refute EDA.Subscription.renewing?(second)
    end

    test "an error is passed through rather than parsed", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/skus/sku1/subscriptions", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(403, Jason.encode!(%{"code" => 50_013, "message" => "Missing Access"}))
      end)

      assert {:error, %{code: 50_013}} = EDA.Subscription.list("sku1")
    end
  end
end
