defmodule EDA.Cache.VoiceStateTest do
  use ExUnit.Case

  describe "get/2" do
    test "returns nil for unknown user" do
      assert EDA.Cache.VoiceState.get("g_unknown", "u_unknown") == nil
    end

    test "returns voice state after upsert" do
      EDA.Cache.VoiceState.upsert("vs_g1", %{
        "user_id" => "vs_u1",
        "channel_id" => "vs_ch1",
        "self_mute" => false,
        "self_deaf" => false
      })

      vs = EDA.Cache.VoiceState.get("vs_g1", "vs_u1")
      assert vs["channel_id"] == "vs_ch1"
      assert vs["guild_id"] == "vs_g1"
    end
  end

  describe "upsert/2" do
    test "removes entry when channel_id is nil (user left voice)" do
      EDA.Cache.VoiceState.upsert("vs_g2", %{
        "user_id" => "vs_u2",
        "channel_id" => "vs_ch2"
      })

      assert EDA.Cache.VoiceState.get("vs_g2", "vs_u2") != nil

      EDA.Cache.VoiceState.upsert("vs_g2", %{
        "user_id" => "vs_u2",
        "channel_id" => nil
      })

      assert EDA.Cache.VoiceState.get("vs_g2", "vs_u2") == nil
    end

    test "updates existing entry when user moves channels" do
      EDA.Cache.VoiceState.upsert("vs_g3", %{
        "user_id" => "vs_u3",
        "channel_id" => "old_ch"
      })

      EDA.Cache.VoiceState.upsert("vs_g3", %{
        "user_id" => "vs_u3",
        "channel_id" => "new_ch"
      })

      vs = EDA.Cache.VoiceState.get("vs_g3", "vs_u3")
      assert vs["channel_id"] == "new_ch"
    end
  end

  describe "for_guild/1" do
    test "returns all voice states for a guild" do
      EDA.Cache.VoiceState.upsert("vs_fg", %{"user_id" => "fg_u1", "channel_id" => "fg_ch"})
      EDA.Cache.VoiceState.upsert("vs_fg", %{"user_id" => "fg_u2", "channel_id" => "fg_ch"})

      states = EDA.Cache.VoiceState.for_guild("vs_fg")
      assert length(states) >= 2
    end

    test "returns empty list for guild with no voice users" do
      assert EDA.Cache.VoiceState.for_guild("vs_empty") == []
    end
  end

  describe "for_channel/2" do
    test "filters by channel_id" do
      EDA.Cache.VoiceState.upsert("vs_fc", %{"user_id" => "fc_u1", "channel_id" => "fc_ch1"})
      EDA.Cache.VoiceState.upsert("vs_fc", %{"user_id" => "fc_u2", "channel_id" => "fc_ch1"})
      EDA.Cache.VoiceState.upsert("vs_fc", %{"user_id" => "fc_u3", "channel_id" => "fc_ch2"})

      ch1 = EDA.Cache.VoiceState.for_channel("vs_fc", "fc_ch1")
      assert length(ch1) == 2

      ch2 = EDA.Cache.VoiceState.for_channel("vs_fc", "fc_ch2")
      assert length(ch2) == 1
    end
  end

  describe "delete_guild/1" do
    test "removes all voice states for a guild" do
      EDA.Cache.VoiceState.upsert("vs_dg", %{"user_id" => "dg_u1", "channel_id" => "dg_ch"})
      EDA.Cache.VoiceState.upsert("vs_dg", %{"user_id" => "dg_u2", "channel_id" => "dg_ch"})

      EDA.Cache.VoiceState.delete_guild("vs_dg")

      assert EDA.Cache.VoiceState.for_guild("vs_dg") == []
    end
  end

  describe "Cache facade" do
    test "get_voice_state delegates correctly" do
      EDA.Cache.VoiceState.upsert("facade_g", %{
        "user_id" => "facade_u",
        "channel_id" => "facade_ch"
      })

      vs = EDA.Cache.get_voice_state("facade_g", "facade_u")
      assert vs["channel_id"] == "facade_ch"
    end

    test "voice_channel_members delegates correctly" do
      EDA.Cache.VoiceState.upsert("vcm_g", %{"user_id" => "vcm_u1", "channel_id" => "vcm_ch"})
      EDA.Cache.VoiceState.upsert("vcm_g", %{"user_id" => "vcm_u2", "channel_id" => "vcm_ch"})

      members = EDA.Cache.voice_channel_members("vcm_g", "vcm_ch")
      assert length(members) == 2
    end
  end
end
