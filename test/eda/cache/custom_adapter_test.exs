defmodule EDA.Cache.CustomAdapterTest do
  @moduledoc """
  Proves the central claim of `EDA.Cache.Adapter`: that a backend written outside EDA only
  has to answer "where does this live", and inherits admission policy, eviction and
  telemetry from the layer above.

  The adapter here is deliberately **not** ETS — it is an Agent holding plain maps — so a
  passing suite means the contract is genuinely sufficient and nothing leaks an ETS
  assumption through.
  """

  # NOT async — swaps the globally configured adapter and uses the shared caches.
  use ExUnit.Case

  defmodule MapAdapter do
    @moduledoc false
    @behaviour EDA.Cache.Adapter

    def start_link, do: Agent.start_link(fn -> %{} end, name: __MODULE__)
    def reset, do: Agent.update(__MODULE__, fn _ -> %{} end)
    def raw(table), do: Agent.get(__MODULE__, &Map.get(&1, table, %{}))

    @impl true
    def init(table, _opts) do
      Agent.update(__MODULE__, &Map.put_new(&1, table, %{}))
    end

    @impl true
    def get(table, key) do
      Agent.get(__MODULE__, fn state -> state |> Map.get(table, %{}) |> Map.get(key) end)
    end

    @impl true
    def put(table, key, value) do
      Agent.update(__MODULE__, fn state ->
        Map.update(state, table, %{key => value}, &Map.put(&1, key, value))
      end)
    end

    @impl true
    def delete(table, key) do
      Agent.update(__MODULE__, fn state ->
        Map.update(state, table, %{}, &Map.delete(&1, key))
      end)
    end

    @impl true
    def all(table) do
      Agent.get(__MODULE__, fn state -> state |> Map.get(table, %{}) |> Map.values() end)
    end

    @impl true
    def count(table) do
      Agent.get(__MODULE__, fn state -> state |> Map.get(table, %{}) |> map_size() end)
    end

    @impl true
    def match_prefix(table, prefix) do
      Agent.get(__MODULE__, fn state ->
        state
        |> Map.get(table, %{})
        |> Enum.filter(&match?({{^prefix, _}, _}, &1))
        |> Enum.map(fn {_key, value} -> value end)
      end)
    end

    @impl true
    def delete_prefix(table, prefix) do
      Agent.get_and_update(__MODULE__, fn state ->
        entries = Map.get(state, table, %{})
        {hit, kept} = Enum.split_with(entries, &match?({{^prefix, _}, _}, &1))
        removed = Enum.map(hit, fn {{_prefix, sub}, _value} -> sub end)
        {removed, Map.put(state, table, Map.new(kept))}
      end)
    end
  end

  setup do
    start_supervised!(%{id: MapAdapter, start: {MapAdapter, :start_link, []}})

    Application.put_env(:eda, :cache_adapter, MapAdapter)
    EDA.Cache.Config.setup()

    # The caches created their tables against ETS at boot; give the new adapter its own.
    for table <- [
          :eda_guilds,
          :eda_users,
          :eda_channels,
          :eda_channels_index,
          :eda_members,
          :eda_roles,
          :eda_roles_index,
          :eda_presences,
          :eda_voice_states
        ] do
      :ok = MapAdapter.init(table, [])
    end

    on_exit(fn ->
      Application.delete_env(:eda, :cache_adapter)
      Application.delete_env(:eda, :cache)
      EDA.Cache.Config.setup()
    end)

    :ok
  end

  describe "every cache works through a third-party adapter" do
    test "guilds — flat key" do
      EDA.Cache.Guild.create(%{"id" => "ca_g1", "name" => "Custom"})

      assert EDA.Cache.get_guild("ca_g1")["name"] == "Custom"
      assert EDA.Cache.Guild.count() == 1
      assert EDA.Cache.Guild.all() |> Enum.map(& &1["id"]) == ["ca_g1"]

      EDA.Cache.Guild.delete("ca_g1")
      assert EDA.Cache.get_guild("ca_g1") == nil
    end

    test "users — flat key" do
      EDA.Cache.User.create(%{"id" => "ca_u1", "username" => "someone"})

      assert EDA.Cache.get_user("ca_u1")["username"] == "someone"
    end

    test "members — composite key and per-guild lookup" do
      EDA.Cache.Member.create("ca_g2", %{"user" => %{"id" => "ca_u2"}, "roles" => []})
      EDA.Cache.Member.create("ca_g2", %{"user" => %{"id" => "ca_u3"}, "roles" => []})
      EDA.Cache.Member.create("ca_other", %{"user" => %{"id" => "ca_u4"}, "roles" => []})

      assert EDA.Cache.get_member("ca_g2", "ca_u2")
      assert length(EDA.Cache.members("ca_g2")) == 2

      EDA.Cache.Member.delete_guild("ca_g2")

      assert EDA.Cache.members("ca_g2") == []
      assert length(EDA.Cache.members("ca_other")) == 1
    end

    test "roles — composite key plus a secondary index" do
      EDA.Cache.Role.create("ca_g3", %{"id" => "ca_r1", "name" => "Admin"})

      # looked up by bare id, which only works through the index
      assert EDA.Cache.Role.get("ca_r1")["name"] == "Admin"
      assert length(EDA.Cache.Role.for_guild("ca_g3")) == 1

      EDA.Cache.Role.delete("ca_r1")

      assert EDA.Cache.Role.get("ca_r1") == nil
      assert MapAdapter.get(:eda_roles_index, "ca_r1") == nil
    end

    test "channels — index cleanup on delete_guild goes through delete_prefix" do
      EDA.Cache.Channel.create(%{"id" => "ca_c1", "guild_id" => "ca_g4", "type" => 0})
      EDA.Cache.Channel.create(%{"id" => "ca_c2", "guild_id" => "ca_g4", "type" => 0})

      assert EDA.Cache.get_channel("ca_c1")
      assert length(EDA.Cache.channels_for_guild("ca_g4")) == 2

      EDA.Cache.Channel.delete_guild("ca_g4")

      assert EDA.Cache.get_channel("ca_c1") == nil
      assert MapAdapter.get(:eda_channels_index, "ca_c1") == nil
      assert MapAdapter.get(:eda_channels_index, "ca_c2") == nil
    end

    test "a DM channel has no guild_id and still round-trips" do
      EDA.Cache.Channel.create(%{"id" => "ca_dm1", "type" => 1})

      assert EDA.Cache.get_channel("ca_dm1")["type"] == 1
    end

    test "presences and voice states" do
      EDA.Cache.Presence.upsert("ca_g5", %{"user" => %{"id" => "ca_u5"}, "status" => "online"})

      assert EDA.Cache.get_presence("ca_g5", "ca_u5")["status"] == "online"

      EDA.Cache.VoiceState.upsert("ca_g5", %{
        "user_id" => "ca_u5",
        "channel_id" => "ca_vc1",
        "session_id" => "s"
      })

      assert EDA.Cache.get_voice_state("ca_g5", "ca_u5")["channel_id"] == "ca_vc1"
    end

    test "nothing reached ETS — the caches really used the custom adapter" do
      EDA.Cache.Guild.create(%{"id" => "ca_not_ets", "name" => "Custom"})

      assert MapAdapter.get(:eda_guilds, "ca_not_ets")["name"] == "Custom"
      assert :ets.lookup(:eda_guilds, "ca_not_ets") == []
    end
  end

  describe "the layer above the adapter still applies" do
    test "an admission policy is honoured, so a backend never implements filtering" do
      Application.put_env(:eda, :cache,
        guilds: [
          policy: fn _entity, _key, guild ->
            if guild["name"] == "keep", do: :cache, else: :skip
          end
        ]
      )

      EDA.Cache.Config.setup()

      EDA.Cache.Guild.create(%{"id" => "ca_keep", "name" => "keep"})
      EDA.Cache.Guild.create(%{"id" => "ca_drop", "name" => "drop"})

      assert EDA.Cache.get_guild("ca_keep")
      refute EDA.Cache.get_guild("ca_drop")
    end

    test "telemetry is emitted from above, not from the backend" do
      test_pid = self()

      :telemetry.attach_many(
        "custom-adapter-telemetry",
        [[:eda, :cache, :write], [:eda, :cache, :hit], [:eda, :cache, :miss]],
        fn event, _measurements, meta, _config -> send(test_pid, {:telemetry, event, meta}) end,
        nil
      )

      on_exit(fn -> :telemetry.detach("custom-adapter-telemetry") end)

      EDA.Cache.Guild.create(%{"id" => "ca_tel", "name" => "T"})
      EDA.Cache.get_guild("ca_tel")
      EDA.Cache.get_guild("ca_absent")

      assert_receive {:telemetry, [:eda, :cache, :write], %{cache: :guilds}}
      assert_receive {:telemetry, [:eda, :cache, :hit], %{cache: :guilds}}
      assert_receive {:telemetry, [:eda, :cache, :miss], %{cache: :guilds}}
    end

    test "eviction removes entries through the adapter, not through ETS" do
      ts = :eda_custom_evict_ts
      ord = :eda_custom_evict_ord

      for t <- [ts, ord] do
        if :ets.whereis(t) != :undefined, do: :ets.delete(t)
      end

      :ets.new(ts, [:set, :public, :named_table])
      :ets.new(ord, [:ordered_set, :public, :named_table])
      :persistent_term.put({:eda_evictor, :eda_guilds}, {ts, ord, 3})
      on_exit(fn -> :persistent_term.erase({:eda_evictor, :eda_guilds}) end)

      for i <- 1..6 do
        EDA.Cache.Guild.create(%{"id" => "ca_ev#{i}", "name" => "G#{i}"})
        Process.sleep(1)
      end

      assert EDA.Cache.Guild.count() == 6

      EDA.Cache.Evictor.evict_table(:eda_guilds, ts, ord, 3)

      assert EDA.Cache.Guild.count() == 3
      # the oldest went first
      refute EDA.Cache.get_guild("ca_ev1")
      assert EDA.Cache.get_guild("ca_ev6")
    end
  end
end
