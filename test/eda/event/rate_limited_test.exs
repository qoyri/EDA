defmodule EDA.Event.RateLimitedTest do
  use ExUnit.Case, async: true

  alias EDA.Event.RateLimited

  describe "from_raw/1" do
    test "flattens guild_id and nonce out of meta" do
      event =
        RateLimited.from_raw(%{
          "opcode" => 8,
          "retry_after" => 12.5,
          "meta" => %{"guild_id" => "123", "nonce" => "abc"}
        })

      assert event.opcode == 8
      assert event.retry_after == 12.5
      assert event.guild_id == "123"
      assert event.nonce == "abc"
      assert event.meta == %{"guild_id" => "123", "nonce" => "abc"}
    end

    test "tolerates a missing meta" do
      event = RateLimited.from_raw(%{"opcode" => 2, "retry_after" => 1.0})

      assert event.opcode == 2
      assert event.guild_id == nil
      assert event.nonce == nil
      assert event.meta == nil
    end
  end

  describe "event routing" do
    test "EDA.Event.from_raw/2 builds the struct" do
      assert %RateLimited{opcode: 8, guild_id: "123"} =
               EDA.Event.from_raw("RATE_LIMITED", %{
                 "opcode" => 8,
                 "retry_after" => 3.0,
                 "meta" => %{"guild_id" => "123"}
               })
    end
  end
end
