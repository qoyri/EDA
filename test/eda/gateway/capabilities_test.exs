defmodule EDA.Gateway.CapabilitiesTest do
  # NOT async: the EDA.capabilities/0 tests mutate the global :eda application env,
  # which every other test shares. See "Flaky tests: suspect shared state first".
  use ExUnit.Case

  alias EDA.Gateway.Capabilities

  doctest EDA.Gateway.Capabilities

  describe "all_capabilities/0" do
    test "returns known capability atoms" do
      assert :channel_obfuscation in Capabilities.all_capabilities()
      assert Enum.all?(Capabilities.all_capabilities(), &is_atom/1)
    end
  end

  describe "to_bitfield/1" do
    test "an empty list means no capabilities" do
      assert Capabilities.to_bitfield([]) == 0
    end

    test "nil means no capabilities" do
      assert Capabilities.to_bitfield(nil) == 0
    end

    test "channel_obfuscation is 1 <<< 15, as Discord documents it" do
      assert Capabilities.to_bitfield([:channel_obfuscation]) == 32_768
    end

    test "accepts a bare atom" do
      assert Capabilities.to_bitfield(:channel_obfuscation) == 32_768
    end

    test "passes a raw integer through, so future capabilities need no release" do
      assert Capabilities.to_bitfield(1_234) == 1_234
      assert Capabilities.to_bitfield(0) == 0
    end

    test "raises on an unknown capability rather than silently sending nothing" do
      assert_raise ArgumentError, ~r/Unknown gateway capability/, fn ->
        Capabilities.to_bitfield([:not_a_capability])
      end
    end
  end

  describe "has_capability?/2" do
    test "detects a set bit" do
      bitfield = Capabilities.to_bitfield([:channel_obfuscation])
      assert Capabilities.has_capability?(bitfield, :channel_obfuscation)
    end

    test "is false when unset" do
      refute Capabilities.has_capability?(0, :channel_obfuscation)
    end

    test "is false for an unknown capability instead of raising" do
      refute Capabilities.has_capability?(0xFFFF, :not_a_capability)
    end
  end

  describe "EDA.Gateway.Connection.maybe_add_capabilities/1" do
    # Exercises the real function in EDA.Gateway.Connection, not a copy of it.
    # Lives here rather than in connection_test.exs because that file is async and
    # these mutate the global :eda application env.
    alias EDA.Gateway.Connection

    setup do
      on_exit(fn -> Application.delete_env(:eda, :capabilities) end)
      :ok
    end

    test "omits the field entirely when nothing is configured" do
      Application.delete_env(:eda, :capabilities)

      assert Connection.maybe_add_capabilities(%{token: "t", intents: 0}) == %{
               token: "t",
               intents: 0
             }
    end

    test "adds the bitfield when a capability is configured" do
      Application.put_env(:eda, :capabilities, [:channel_obfuscation])

      assert Connection.maybe_add_capabilities(%{token: "t", intents: 0}).capabilities == 32_768
    end

    test "accepts a raw bitfield" do
      Application.put_env(:eda, :capabilities, 41)

      assert Connection.maybe_add_capabilities(%{}).capabilities == 41
    end

    test "an explicit zero still omits the field" do
      Application.put_env(:eda, :capabilities, 0)

      refute Map.has_key?(Connection.maybe_add_capabilities(%{}), :capabilities)
    end
  end

  describe "EDA.capabilities/0" do
    test "defaults to 0 so IDENTIFY is unchanged" do
      assert EDA.capabilities() == 0
    end

    test "reads the application env" do
      Application.put_env(:eda, :capabilities, [:channel_obfuscation])
      on_exit(fn -> Application.delete_env(:eda, :capabilities) end)

      assert EDA.capabilities() == 32_768
    end
  end
end
