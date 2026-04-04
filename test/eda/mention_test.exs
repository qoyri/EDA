defmodule EDA.MentionTest do
  use ExUnit.Case, async: true

  alias EDA.Mention

  describe "user/1" do
    test "formats user mention" do
      assert Mention.user("123456") == "<@123456>"
      assert Mention.user(123_456) == "<@123456>"
    end
  end

  describe "channel/1" do
    test "formats channel mention" do
      assert Mention.channel("789") == "<#789>"
      assert Mention.channel(789) == "<#789>"
    end
  end

  describe "role/1" do
    test "formats role mention" do
      assert Mention.role("456") == "<@&456>"
      assert Mention.role(456) == "<@&456>"
    end
  end

  describe "emoji/3" do
    test "formats static emoji" do
      assert Mention.emoji("wave", "123") == "<:wave:123>"
    end

    test "formats animated emoji" do
      assert Mention.emoji("wave", "123", true) == "<a:wave:123>"
    end
  end

  describe "timestamp/2" do
    test "formats timestamp without style" do
      assert Mention.timestamp(1_700_000_000) == "<t:1700000000>"
    end

    test "formats timestamp with relative style" do
      assert Mention.timestamp(1_700_000_000, :R) == "<t:1700000000:R>"
    end

    test "formats all valid styles" do
      assert Mention.timestamp(0, :t) == "<t:0:t>"
      assert Mention.timestamp(0, :T) == "<t:0:T>"
      assert Mention.timestamp(0, :d) == "<t:0:d>"
      assert Mention.timestamp(0, :D) == "<t:0:D>"
      assert Mention.timestamp(0, :f) == "<t:0:f>"
      assert Mention.timestamp(0, :F) == "<t:0:F>"
      assert Mention.timestamp(0, :R) == "<t:0:R>"
    end

    test "raises on invalid style" do
      assert_raise ArgumentError, ~r/unknown timestamp style/, fn ->
        Mention.timestamp(0, :invalid)
      end
    end
  end
end
