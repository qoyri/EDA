defmodule EDA.Cache.ChannelTest do
  use ExUnit.Case

  alias EDA.Cache.Channel

  describe "create/1 and get/1" do
    test "stores and retrieves a guild channel" do
      channel = %{"id" => "ch1", "name" => "general", "guild_id" => "g1"}
      Channel.create(channel)

      cached = Channel.get("ch1")
      assert cached["name"] == "general"
      assert cached["guild_id"] == "g1"
    end

    test "stores and retrieves a DM channel (no guild_id)" do
      channel = %{"id" => "dm1", "name" => nil, "type" => 1}
      Channel.create(channel)

      cached = Channel.get("dm1")
      assert cached["type"] == 1
      assert cached["guild_id"] == nil
    end

    test "returns nil for unknown channel" do
      assert Channel.get("ch_unknown") == nil
    end

    test "accepts integer IDs" do
      Channel.create(%{"id" => "ch_int", "guild_id" => "g_int", "name" => "int"})
      assert Channel.get("ch_int") != nil
    end
  end

  describe "for_guild/1" do
    test "returns channels for a specific guild" do
      Channel.create(%{"id" => "fg1", "guild_id" => "fg_guild", "name" => "text"})
      Channel.create(%{"id" => "fg2", "guild_id" => "fg_guild", "name" => "voice"})
      Channel.create(%{"id" => "fg3", "guild_id" => "fg_other", "name" => "other"})

      channels = Channel.for_guild("fg_guild")
      assert length(channels) >= 2
      names = Enum.map(channels, & &1["name"])
      assert "text" in names
      assert "voice" in names
      refute "other" in names
    end

    test "returns empty list for unknown guild" do
      assert Channel.for_guild("nonexistent_guild") == []
    end
  end

  describe "update/2" do
    test "merges fields into existing channel" do
      Channel.create(%{"id" => "cu1", "guild_id" => "cu_g", "name" => "old", "type" => 0})
      Channel.update("cu1", %{"name" => "new"})

      cached = Channel.get("cu1")
      assert cached["name"] == "new"
      assert cached["type"] == 0
    end

    test "returns nil for unknown channel" do
      assert Channel.update("cu_unknown", %{"name" => "x"}) == nil
    end
  end

  describe "delete/1" do
    test "removes a channel" do
      Channel.create(%{"id" => "cd1", "guild_id" => "cd_g", "name" => "gone"})
      Channel.delete("cd1")
      assert Channel.get("cd1") == nil
    end

    test "delete is idempotent" do
      Channel.delete("cd_nonexistent")
      assert :ok == Channel.delete("cd_nonexistent")
    end
  end

  describe "delete_guild/1" do
    test "removes all channels for a guild" do
      Channel.create(%{"id" => "dg1", "guild_id" => "dg_guild", "name" => "a"})
      Channel.create(%{"id" => "dg2", "guild_id" => "dg_guild", "name" => "b"})
      Channel.create(%{"id" => "dg3", "guild_id" => "dg_keep", "name" => "keep"})

      Channel.delete_guild("dg_guild")

      assert Channel.for_guild("dg_guild") == []
      assert Channel.get("dg1") == nil
      assert Channel.get("dg2") == nil
      assert Channel.get("dg3") != nil
    end
  end

  describe "all/0 and count/0" do
    test "count reflects insertions" do
      before = Channel.count()
      Channel.create(%{"id" => "cnt1", "guild_id" => "cnt_g", "name" => "x"})
      assert Channel.count() >= before + 1
    end
  end

  describe "performance" do
    # for_guild matches on a partial key, which on a :set table is a scan of every channel in
    # the cache — including the ones other tests left behind — so its time depends on the
    # environment. Measured on 10k channels: median 5ms, p90 9ms, worst 13ms. The old 10ms
    # bound sat inside that spread and failed about one run in twenty.
    #
    # What this guards against is an algorithmic regression, not a few milliseconds: an
    # O(n²) implementation takes seconds here. So it takes the best of five runs (noise only
    # ever adds time) against a 50ms ceiling, roughly ten times the worst case observed.
    test "for_guild on 10k channels stays fast (best of 5 under 50ms)" do
      guild_id = "perf_guild_#{System.unique_integer([:positive])}"

      for i <- 1..10_000 do
        Channel.create(%{
          "id" => "perf_#{guild_id}_#{i}",
          "guild_id" => guild_id,
          "name" => "channel-#{i}"
        })
      end

      assert length(Channel.for_guild(guild_id)) == 10_000

      best_us =
        1..5
        |> Enum.map(fn _ -> :timer.tc(fn -> Channel.for_guild(guild_id) end) |> elem(0) end)
        |> Enum.min()

      assert best_us < 50_000, "for_guild took #{best_us}us at best of 5, expected < 50ms"

      # Cleanup
      Channel.delete_guild(guild_id)
    end
  end

  describe "Cache facade" do
    test "get_channel delegates correctly" do
      Channel.create(%{"id" => "cf1", "guild_id" => "cf_g", "name" => "facade"})
      assert EDA.Cache.get_channel("cf1")["name"] == "facade"
    end

    test "channels_for_guild delegates correctly" do
      Channel.create(%{"id" => "cf2", "guild_id" => "cf_g2", "name" => "a"})
      channels = EDA.Cache.channels_for_guild("cf_g2")
      assert channels != []
    end
  end
end
