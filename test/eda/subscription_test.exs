defmodule EDA.SubscriptionTest do
  @moduledoc """
  Covers the subscription struct and, above all, the status enum.

  Discord renumbered that enum on 2026-06-16 — `INACTIVE` and `ENDING` traded values — so
  the integers are asserted explicitly here. A silent swap is the failure this module exists
  to prevent, and it is one no type checker would catch.
  """

  use ExUnit.Case, async: true

  alias EDA.Subscription

  doctest EDA.Subscription

  describe "from_raw/1" do
    test "parses the whole object" do
      sub =
        Subscription.from_raw(%{
          "id" => "s1",
          "user_id" => "u1",
          "sku_ids" => ["sku1"],
          "entitlement_ids" => ["e1"],
          "renewal_sku_ids" => ["sku2"],
          "current_period_start" => "2026-09-01T00:00:00Z",
          "current_period_end" => "2026-10-01T00:00:00Z",
          "status" => 2,
          "canceled_at" => "2026-09-19T12:00:00Z",
          "country" => "FR"
        })

      assert sub.id == "s1"
      assert sub.user_id == "u1"
      assert sub.sku_ids == ["sku1"]
      assert sub.entitlement_ids == ["e1"]
      assert sub.renewal_sku_ids == ["sku2"]
      assert sub.current_period_end == ~U[2026-10-01 00:00:00Z]
      assert sub.status == :ending
      assert sub.country == "FR"
    end

    test "the optional fields are nil rather than missing" do
      sub = Subscription.from_raw(%{"id" => "s1", "status" => 0})

      assert sub.renewal_sku_ids == nil
      assert sub.canceled_at == nil
      # `country` is absent unless the caller has the right scope
      assert sub.country == nil
    end
  end

  describe "status/1 — the values Discord renumbered" do
    test "the current numbering, stated explicitly" do
      assert Subscription.status(0) == :active
      assert Subscription.status(1) == :inactive
      assert Subscription.status(2) == :ending
    end

    test "reads a struct, a raw map or a bare integer" do
      assert Subscription.status(%Subscription{status: 1}) == :inactive
      assert Subscription.status(%{"status" => 1}) == :inactive
    end

    test "a value Discord adds later does not crash a case" do
      assert Subscription.status(%Subscription{status: 99}) == :unknown
      assert Subscription.status(nil) == :unknown
      assert Subscription.status(%Subscription{}) == :unknown
    end
  end

  describe "status_value/1" do
    test "round-trips with status/1" do
      for name <- [:active, :inactive, :ending] do
        assert name |> Subscription.status_value() |> Subscription.status() == name
      end
    end

    test "an unknown name has no integer" do
      assert Subscription.status_value(:nonsense) == nil
      assert Subscription.status_value(:unknown) == nil
    end
  end

  describe "renewing?/1" do
    test "only :active renews — :ending is running but will stop" do
      assert Subscription.renewing?(%Subscription{status: 0})
      refute Subscription.renewing?(%Subscription{status: 1})
      refute Subscription.renewing?(%Subscription{status: 2})
    end

    test "an unknown status is not assumed to renew" do
      refute Subscription.renewing?(%Subscription{status: 99})
      refute Subscription.renewing?(%Subscription{})
    end
  end

  describe "canceled?/1" do
    test "reads canceled_at, which is set the moment the user cancels" do
      assert Subscription.canceled?(%Subscription{canceled_at: "2026-09-19T12:00:00Z"})
      refute Subscription.canceled?(%Subscription{canceled_at: nil})
    end

    test "a cancelled subscription is still :ending until the period runs out" do
      sub = %Subscription{status: 2, canceled_at: "2026-09-19T12:00:00Z"}

      assert Subscription.canceled?(sub)
      assert Subscription.status(sub) == :ending
      refute Subscription.renewing?(sub)
    end

    test "raw maps are accepted" do
      assert Subscription.canceled?(%{"canceled_at" => "2026-09-19T12:00:00Z"})
      refute Subscription.canceled?(%{"canceled_at" => nil})
      refute Subscription.canceled?(%{"id" => "s1"})
    end
  end

  describe "changing_plan?/1" do
    test "true when the renewal SKUs differ from the current ones" do
      assert Subscription.changing_plan?(%Subscription{
               sku_ids: ["basic"],
               renewal_sku_ids: ["premium"]
             })
    end

    test "false when nothing is changing" do
      refute Subscription.changing_plan?(%Subscription{sku_ids: ["a"], renewal_sku_ids: nil})
      refute Subscription.changing_plan?(%Subscription{sku_ids: ["a"], renewal_sku_ids: ["a"]})
    end

    test "order is not a change" do
      refute Subscription.changing_plan?(%Subscription{
               sku_ids: ["a", "b"],
               renewal_sku_ids: ["b", "a"]
             })
    end

    test "dropping every SKU at renewal counts as a change" do
      assert Subscription.changing_plan?(%Subscription{sku_ids: ["a"], renewal_sku_ids: []})
    end

    test "raw maps are accepted" do
      assert Subscription.changing_plan?(%{"sku_ids" => ["a"], "renewal_sku_ids" => ["b"]})
    end
  end

  describe "Access" do
    test "a field is reachable three ways, like every other entity" do
      sub = Subscription.from_raw(%{"id" => "s1", "status" => 0})

      assert sub.id == "s1"
      assert sub[:id] == "s1"
      assert sub["id"] == "s1"
    end
  end
end
