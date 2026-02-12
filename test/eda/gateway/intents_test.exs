defmodule EDA.Gateway.IntentsTest do
  use ExUnit.Case, async: true

  alias EDA.Gateway.Intents

  describe "all_intents/0" do
    test "returns a list of atoms" do
      intents = Intents.all_intents()
      assert is_list(intents)
      assert Enum.all?(intents, &is_atom/1)
    end

    test "includes common intents" do
      intents = Intents.all_intents()
      assert :guilds in intents
      assert :guild_messages in intents
      assert :message_content in intents
      assert :guild_voice_states in intents
      assert :direct_messages in intents
    end

    test "returns 21 intents" do
      assert length(Intents.all_intents()) == 21
    end
  end

  describe "privileged_intents/0" do
    test "returns exactly three privileged intents" do
      priv = Intents.privileged_intents()
      assert length(priv) == 3
      assert :guild_members in priv
      assert :guild_presences in priv
      assert :message_content in priv
    end
  end

  describe "nonprivileged_intents/0" do
    test "does not include privileged intents" do
      non_priv = Intents.nonprivileged_intents()
      refute :guild_members in non_priv
      refute :guild_presences in non_priv
      refute :message_content in non_priv
    end

    test "is all_intents minus privileged" do
      assert length(Intents.nonprivileged_intents()) ==
               length(Intents.all_intents()) - length(Intents.privileged_intents())
    end
  end

  describe "to_bitfield/1" do
    test "converts single intent" do
      assert Intents.to_bitfield([:guilds]) == 1
    end

    test "converts multiple intents" do
      result = Intents.to_bitfield([:guilds, :guild_messages])
      assert result == Bitwise.bor(1, Bitwise.bsl(1, 9))
      assert result == 513
    end

    test "converts :all shortcut" do
      bitfield = Intents.to_bitfield(:all)
      assert is_integer(bitfield)
      assert bitfield > 0

      # Every intent should be present
      for intent <- Intents.all_intents() do
        assert Intents.has_intent?(bitfield, intent),
               "Expected #{intent} in :all bitfield"
      end
    end

    test "converts :nonprivileged shortcut" do
      bitfield = Intents.to_bitfield(:nonprivileged)
      assert is_integer(bitfield)

      refute Intents.has_intent?(bitfield, :guild_members)
      refute Intents.has_intent?(bitfield, :guild_presences)
      refute Intents.has_intent?(bitfield, :message_content)

      assert Intents.has_intent?(bitfield, :guilds)
      assert Intents.has_intent?(bitfield, :guild_messages)
    end

    test "empty list returns 0" do
      assert Intents.to_bitfield([]) == 0
    end

    test "raises on unknown intent" do
      assert_raise ArgumentError, ~r/Unknown intent/, fn ->
        Intents.to_bitfield([:fake_intent])
      end
    end

    test "guild_voice_states is bit 7" do
      assert Intents.to_bitfield([:guild_voice_states]) == 128
    end
  end

  describe "has_intent?/2" do
    test "returns true when intent is set" do
      bitfield = Intents.to_bitfield([:guilds, :guild_messages])
      assert Intents.has_intent?(bitfield, :guilds)
      assert Intents.has_intent?(bitfield, :guild_messages)
    end

    test "returns false when intent is not set" do
      bitfield = Intents.to_bitfield([:guilds])
      refute Intents.has_intent?(bitfield, :guild_messages)
      refute Intents.has_intent?(bitfield, :message_content)
    end

    test "returns false for unknown intent" do
      bitfield = Intents.to_bitfield(:all)
      refute Intents.has_intent?(bitfield, :not_a_real_intent)
    end

    test "returns false for zero bitfield" do
      refute Intents.has_intent?(0, :guilds)
    end
  end
end
