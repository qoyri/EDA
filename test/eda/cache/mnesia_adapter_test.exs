defmodule EDA.Cache.MnesiaAdapterTest do
  @moduledoc """
  Runs the adapter contract against a real Mnesia instance.

  Mnesia is started for the duration of these tests only — EDA does not list it in
  `:extra_applications`, so a bot that never configures this adapter never pays for it.

  Deliberately uses a table name of its own. Running the seven *caches* on Mnesia cannot
  be done inside this suite: Mnesia backs a `ram_copies` table with an ETS table of the
  same name, so it would have to take the cache table names away from the ETS adapter for
  the whole VM. That path is validated end to end against the live gateway with the test
  bot instead.
  """

  # NOT async — starts Mnesia and swaps the globally configured adapter.
  use ExUnit.Case

  alias EDA.Cache.Adapter.Mnesia, as: Subject

  @table :eda_mnesia_contract_test

  setup_all do
    :mnesia.start()

    on_exit(fn -> :mnesia.stop() end)

    :ok
  end

  setup do
    :ok = Subject.init(@table, [])

    on_exit(fn ->
      :mnesia.clear_table(@table)
    end)

    :ok
  end

  describe "the contract, against real Mnesia" do
    test "init is idempotent — a second call on an existing table is fine" do
      assert Subject.init(@table, []) == :ok
      assert Subject.init(@table, []) == :ok
    end

    test "get returns nil for an absent key" do
      assert Subject.get(@table, "absent") == nil
    end

    test "put then get round-trips, and put replaces" do
      :ok = Subject.put(@table, "k", %{"v" => 1})
      assert Subject.get(@table, "k") == %{"v" => 1}

      :ok = Subject.put(@table, "k", %{"v" => 2})
      assert Subject.get(@table, "k") == %{"v" => 2}
      assert Subject.count(@table) == 1
    end

    test "delete is idempotent" do
      :ok = Subject.put(@table, "k", %{})
      assert Subject.delete(@table, "k") == :ok
      assert Subject.delete(@table, "k") == :ok
      assert Subject.get(@table, "k") == nil
    end

    test "all and count" do
      :ok = Subject.put(@table, "a", %{"n" => 1})
      :ok = Subject.put(@table, "b", %{"n" => 2})

      assert Subject.count(@table) == 2
      assert Subject.all(@table) |> Enum.sort_by(& &1["n"]) == [%{"n" => 1}, %{"n" => 2}]
    end

    test "composite keys: match_prefix selects only its own group" do
      :ok = Subject.put(@table, {"g1", "a"}, %{"id" => "a"})
      :ok = Subject.put(@table, {"g1", "b"}, %{"id" => "b"})
      :ok = Subject.put(@table, {"g2", "c"}, %{"id" => "c"})

      assert Subject.match_prefix(@table, "g1") |> Enum.map(& &1["id"]) |> Enum.sort() ==
               ["a", "b"]

      assert Subject.match_prefix(@table, "g2") |> Enum.map(& &1["id"]) == ["c"]
      assert Subject.match_prefix(@table, "absent") == []
    end

    test "delete_prefix removes the group and reports the sub-keys" do
      :ok = Subject.put(@table, {"g1", "a"}, %{})
      :ok = Subject.put(@table, {"g1", "b"}, %{})
      :ok = Subject.put(@table, {"g2", "c"}, %{})

      assert Subject.delete_prefix(@table, "g1") |> Enum.sort() == ["a", "b"]
      assert Subject.match_prefix(@table, "g1") == []
      assert Subject.count(@table) == 1
    end

    test "count on a table that does not exist is 0, not a crash" do
      assert Subject.count(:eda_mnesia_never_created) == 0
    end

    test "a stored nil reads back as nil, like any absent key" do
      # Same documented limitation as the ETS adapter; the channel cache indexes the
      # full key rather than a nullable guild_id precisely because of this.
      :ok = Subject.put(@table, "nil_key", nil)

      assert Subject.get(@table, "nil_key") == nil
    end
  end
end
