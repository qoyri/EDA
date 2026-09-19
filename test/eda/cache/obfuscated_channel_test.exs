defmodule EDA.Cache.ObfuscatedChannelTest do
  # NOT async — mutates the global :eda cache config and the shared ETS tables.
  use ExUnit.Case

  alias EDA.Cache
  alias EDA.Channel

  # A guild id per test: the ETS cache is shared across the whole suite, so a channel
  # written by one test would otherwise show up in another's channels_for_guild/1.

  setup do
    on_exit(fn ->
      Application.delete_env(:eda, :cache)
      EDA.Cache.Config.setup()
    end)

    :ok
  end

  defp obfuscated_channel(id, guild_id) do
    %{
      "id" => id,
      "guild_id" => guild_id,
      "type" => 0,
      "name" => Channel.obfuscated_name(),
      "flags" => Channel.flag_obfuscated(),
      "permission_overwrites" => [
        %{"id" => guild_id, "type" => 0, "allow" => "0", "deny" => "1024"}
      ]
    }
  end

  defp visible_channel(id, guild_id) do
    %{
      "id" => id,
      "guild_id" => guild_id,
      "type" => 0,
      "name" => "general",
      "flags" => 0,
      "permission_overwrites" => []
    }
  end

  describe "default behaviour" do
    test "obfuscated channels are cached, not dropped" do
      Cache.Channel.create(obfuscated_channel("obf_ch_1", "obf_guild_default"))

      assert cached = Cache.get_channel("obf_ch_1")
      assert Channel.obfuscated?(cached)
      assert cached["name"] == "___hidden___"
    end

    test "they appear in channels_for_guild/1, so callers must filter" do
      guild_id = "obf_guild_listing"
      Cache.Channel.create(visible_channel("obf_ch_visible", guild_id))
      Cache.Channel.create(obfuscated_channel("obf_ch_hidden", guild_id))

      all = Cache.channels_for_guild(guild_id)
      ids = Enum.map(all, & &1["id"])

      assert "obf_ch_visible" in ids
      assert "obf_ch_hidden" in ids

      # The filter recommended in the EDA.Cache docs.
      visible = Enum.reject(all, &Channel.obfuscated?/1)

      assert Enum.map(visible, & &1["id"]) == ["obf_ch_visible"]
    end
  end

  describe "the opt-out policy documented on EDA.Cache" do
    test "skips obfuscated channels while keeping the rest" do
      # Copied from the EDA.Cache moduledoc — if this breaks, the docs are wrong.
      Application.put_env(:eda, :cache,
        channels: [
          policy: fn _entity, _key, channel ->
            if EDA.Channel.obfuscated?(channel), do: :skip, else: :cache
          end
        ]
      )

      EDA.Cache.Config.setup()

      guild_id = "obf_guild_policy"
      Cache.Channel.create(visible_channel("obf_policy_visible", guild_id))
      Cache.Channel.create(obfuscated_channel("obf_policy_hidden", guild_id))

      assert Cache.get_channel("obf_policy_visible")
      refute Cache.get_channel("obf_policy_hidden")
    end
  end
end
