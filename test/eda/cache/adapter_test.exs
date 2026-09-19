defmodule EDA.Cache.AdapterTest do
  # NOT async — swaps the globally configured adapter.
  use ExUnit.Case

  alias EDA.Cache.Adapter

  setup do
    on_exit(fn ->
      Application.delete_env(:eda, :cache_adapter)
      EDA.Cache.Config.setup()
    end)

    :ok
  end

  describe "resolution" do
    test "defaults to ETS" do
      Application.delete_env(:eda, :cache_adapter)
      EDA.Cache.Config.setup()

      assert Adapter.current() == Adapter.ETS
      assert EDA.Cache.Config.adapter() == Adapter.ETS
    end

    test "is read from config at setup, not per call" do
      Application.put_env(:eda, :cache_adapter, Adapter.NoOp)
      EDA.Cache.Config.setup()

      assert Adapter.current() == Adapter.NoOp
    end
  end

  describe "the ETS adapter satisfies the contract" do
    @table :eda_adapter_contract_test

    setup do
      :ok = Adapter.ETS.init(@table, [])

      on_exit(fn -> if :ets.whereis(@table) != :undefined, do: :ets.delete_all_objects(@table) end)

      :ok
    end

    test "get returns nil for an absent key" do
      assert Adapter.ETS.get(@table, "absent") == nil
    end

    test "put then get round-trips, and put replaces" do
      :ok = Adapter.ETS.put(@table, "k", %{"v" => 1})
      assert Adapter.ETS.get(@table, "k") == %{"v" => 1}

      :ok = Adapter.ETS.put(@table, "k", %{"v" => 2})
      assert Adapter.ETS.get(@table, "k") == %{"v" => 2}
    end

    test "a stored nil is distinguishable from an absent key only by the caller" do
      # Documented limitation: get/2 collapses both to nil, which is why the channel
      # cache indexes the full key rather than a nullable guild_id.
      :ok = Adapter.ETS.put(@table, "nil_key", nil)

      assert Adapter.ETS.get(@table, "nil_key") == nil
      assert Adapter.ETS.get(@table, "absent") == nil
    end

    test "delete is idempotent" do
      :ok = Adapter.ETS.put(@table, "k", %{})
      assert Adapter.ETS.delete(@table, "k") == :ok
      assert Adapter.ETS.delete(@table, "k") == :ok
      assert Adapter.ETS.get(@table, "k") == nil
    end

    test "all and count" do
      :ok = Adapter.ETS.put(@table, "a", %{"n" => 1})
      :ok = Adapter.ETS.put(@table, "b", %{"n" => 2})

      assert Adapter.ETS.count(@table) == 2
      assert Adapter.ETS.all(@table) |> Enum.sort_by(& &1["n"]) == [%{"n" => 1}, %{"n" => 2}]
    end

    test "match_prefix returns only the matching composite keys" do
      :ok = Adapter.ETS.put(@table, {"g1", "a"}, %{"id" => "a"})
      :ok = Adapter.ETS.put(@table, {"g1", "b"}, %{"id" => "b"})
      :ok = Adapter.ETS.put(@table, {"g2", "c"}, %{"id" => "c"})

      assert Adapter.ETS.match_prefix(@table, "g1") |> Enum.map(& &1["id"]) |> Enum.sort() ==
               ["a", "b"]
    end

    test "delete_prefix removes the group and reports the sub-keys" do
      :ok = Adapter.ETS.put(@table, {"g1", "a"}, %{})
      :ok = Adapter.ETS.put(@table, {"g1", "b"}, %{})
      :ok = Adapter.ETS.put(@table, {"g2", "c"}, %{})

      assert Adapter.ETS.delete_prefix(@table, "g1") |> Enum.sort() == ["a", "b"]
      assert Adapter.ETS.match_prefix(@table, "g1") == []
      assert Adapter.ETS.match_prefix(@table, "g2") != []
    end

    test "count on a table that was never created is 0, not a crash" do
      assert Adapter.ETS.count(:eda_never_created_table) == 0
    end
  end

  describe "the NoOp adapter satisfies the contract" do
    test "every callback answers without storing anything" do
      assert Adapter.NoOp.init(:whatever, []) == :ok
      assert Adapter.NoOp.put(:whatever, "k", %{"v" => 1}) == :ok
      assert Adapter.NoOp.get(:whatever, "k") == nil
      assert Adapter.NoOp.delete(:whatever, "k") == :ok
      assert Adapter.NoOp.all(:whatever) == []
      assert Adapter.NoOp.count(:whatever) == 0
      assert Adapter.NoOp.match_prefix(:whatever, "g1") == []
      assert Adapter.NoOp.delete_prefix(:whatever, "g1") == []
    end
  end

  describe "the caches work through whichever adapter is configured" do
    test "with NoOp, writes are discarded and reads miss" do
      Application.put_env(:eda, :cache_adapter, Adapter.NoOp)
      EDA.Cache.Config.setup()

      EDA.Cache.Guild.create(%{"id" => "noop_g1", "name" => "Ghost"})
      EDA.Cache.Role.create("noop_g1", %{"id" => "noop_r1", "name" => "Ghost role"})

      assert EDA.Cache.get_guild("noop_g1") == nil
      assert EDA.Cache.Role.get("noop_r1") == nil
      assert EDA.Cache.Guild.count() == 0
      assert EDA.Cache.Role.for_guild("noop_g1") == []
    end

    test "back on ETS, the same writes are kept" do
      Application.delete_env(:eda, :cache_adapter)
      EDA.Cache.Config.setup()

      EDA.Cache.Guild.create(%{"id" => "ets_g1", "name" => "Real"})

      assert EDA.Cache.get_guild("ets_g1")["name"] == "Real"
    end
  end
end
