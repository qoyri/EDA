defmodule EDA.PermissionClassificationTest do
  use ExUnit.Case, async: true

  alias EDA.Permission

  doctest EDA.Permission,
    only: [channel_types: 1, guild_only?: 1, channel?: 1, applies_to?: 2, inapplicable: 2]

  describe "coverage" do
    test "every permission flag is classified" do
      unclassified =
        Permission.all_flags()
        |> Enum.reject(fn flag ->
          is_list(Permission.channel_types(flag))
        end)

      assert unclassified == []
    end

    test "the twelve guild-only permissions are exactly Discord's list" do
      guild_only = Permission.all_flags() |> Enum.filter(&Permission.guild_only?/1) |> Enum.sort()

      assert guild_only == [
               :administrator,
               :ban_members,
               :change_nickname,
               :create_guild_expressions,
               :kick_members,
               :manage_guild,
               :manage_guild_expressions,
               :manage_nicknames,
               :moderate_members,
               :view_audit_log,
               :view_creator_monetization_analytics,
               :view_guild_insights
             ]
    end

    test "guild_only?/1 and channel?/1 are exact opposites" do
      for flag <- Permission.all_flags() do
        assert Permission.guild_only?(flag) != Permission.channel?(flag),
               "#{flag} is neither or both"
      end
    end
  end

  describe "applies_to?/2" do
    test "a stage-only permission" do
      assert Permission.applies_to?(:request_to_speak, :stage)
      refute Permission.applies_to?(:request_to_speak, :text)
      refute Permission.applies_to?(:request_to_speak, :voice)
    end

    test "a voice-only permission" do
      assert Permission.applies_to?(:speak, :voice)
      refute Permission.applies_to?(:speak, :text)
    end

    test "a guild-only permission applies to no channel at all" do
      for kind <- [:text, :voice, :stage] do
        refute Permission.applies_to?(:kick_members, kind)
      end
    end

    test "accepts raw Discord channel type integers" do
      # 0 text, 2 voice, 13 stage, 5 announcement, 15 forum
      assert Permission.applies_to?(:send_messages, 0)
      assert Permission.applies_to?(:speak, 2)
      assert Permission.applies_to?(:request_to_speak, 13)
      refute Permission.applies_to?(:request_to_speak, 0)
      assert Permission.applies_to?(:send_messages, 5)
      assert Permission.applies_to?(:send_messages, 15)
    end

    test "accepts a channel struct or a raw channel map" do
      assert Permission.applies_to?(:speak, %EDA.Channel{type: 2})
      assert Permission.applies_to?(:speak, %{"type" => 2})
      refute Permission.applies_to?(:speak, %{"type" => 0})
    end

    test "a category accepts every channel permission, since it cascades" do
      # type 4 = GUILD_CATEGORY
      assert Permission.applies_to?(:send_messages, 4)
      assert Permission.applies_to?(:speak, 4)
      assert Permission.applies_to?(:request_to_speak, 4)

      # but still not a guild-level one
      refute Permission.applies_to?(:kick_members, 4)
    end

    test "an unknown channel type applies to nothing rather than raising" do
      refute Permission.applies_to?(:send_messages, 999)
      refute Permission.applies_to?(:send_messages, "nope")
    end
  end

  describe "inapplicable/2" do
    test "catches a guild-level permission put in a channel overwrite" do
      bitset = Permission.to_bitset([:send_messages, :kick_members, :ban_members])

      assert Permission.inapplicable(bitset, :text) == [:ban_members, :kick_members]
    end

    test "catches a permission meant for another channel kind" do
      bitset = Permission.to_bitset([:send_messages, :request_to_speak, :speak])

      assert Permission.inapplicable(bitset, :text) == [:request_to_speak, :speak]
      assert Permission.inapplicable(bitset, :voice) == [:request_to_speak]
      assert Permission.inapplicable(bitset, :stage) == [:speak]
    end

    test "is empty for a well-formed overwrite" do
      bitset = Permission.to_bitset([:send_messages, :embed_links, :attach_files])

      assert Permission.inapplicable(bitset, :text) == []
    end

    test "works from a channel struct" do
      bitset = Permission.to_bitset([:speak, :kick_members])

      assert Permission.inapplicable(bitset, %EDA.Channel{type: 2}) == [:kick_members]
    end

    test "an empty bitset has nothing inapplicable" do
      assert Permission.inapplicable(0, :text) == []
    end
  end
end
