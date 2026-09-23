defmodule EDA.Gateway.Encoding.ETFTest do
  use ExUnit.Case, async: true

  alias EDA.Gateway.Encoding.ETF

  # Helper to create ETF binary from an Elixir term
  defp to_etf(term), do: :erlang.term_to_binary(term)

  describe "decode/1" do
    test "converts atom keys to strings" do
      etf = to_etf(%{op: 10, d: %{heartbeat_interval: 41_250}})
      assert %{"op" => 10, "d" => %{"heartbeat_interval" => 41_250}} = ETF.decode(etf)
    end

    test "converts snowflake integers to strings" do
      etf = to_etf(%{id: 123_456_789_012_345_678})
      assert %{"id" => "123456789012345678"} = ETF.decode(etf)
    end

    test "preserves small integers (OP codes, types)" do
      etf = to_etf(%{op: 0, type: 14})
      assert %{"op" => 0, "type" => 14} = ETF.decode(etf)
    end

    test "preserves booleans and nil" do
      etf = to_etf(%{a: true, b: false, c: nil})
      assert %{"a" => true, "b" => false, "c" => nil} = ETF.decode(etf)
    end

    test "normalizes nested structures" do
      etf = to_etf(%{d: %{user: %{id: 123_456_789_012_345_678, bot: true}, roles: [1, 2, 3]}})

      assert %{
               "d" => %{
                 "user" => %{"id" => "123456789012345678", "bot" => true},
                 "roles" => [1, 2, 3]
               }
             } = ETF.decode(etf)
    end

    test "decodes realistic HELLO payload (OP 10)" do
      hello = %{op: 10, d: %{heartbeat_interval: 41_250}, s: nil, t: nil}
      etf = to_etf(hello)
      decoded = ETF.decode(etf)

      assert decoded["op"] == 10
      assert decoded["d"]["heartbeat_interval"] == 41_250
      assert decoded["s"] == nil
      assert decoded["t"] == nil
    end

    test "decodes dispatch payload (OP 0) with event type string" do
      dispatch = %{op: 0, t: "MESSAGE_CREATE", s: 42, d: %{content: "hello"}}
      etf = to_etf(dispatch)
      decoded = ETF.decode(etf)

      assert decoded["op"] == 0
      assert decoded["t"] == "MESSAGE_CREATE"
      assert decoded["s"] == 42
      assert decoded["d"]["content"] == "hello"
    end

    test "converts permission integers to strings" do
      # Permissions like 1071698529857 are well above the snowflake threshold
      etf = to_etf(%{permissions: 1_071_698_529_857})
      assert %{"permissions" => "1071698529857"} = ETF.decode(etf)
    end
  end

  describe "encode/1" do
    test "returns {:binary, binary} tuple" do
      {:binary, bin} = ETF.encode(%{op: 1, d: nil})
      assert is_binary(bin)
    end

    test "roundtrips correctly" do
      payload = %{op: 1, d: 42}
      {:binary, bin} = ETF.encode(payload)
      assert :erlang.binary_to_term(bin) == %{"op" => 1, "d" => 42}
    end

    test "stringifies atom keys for Discord compatibility" do
      payload = %{op: 2, d: %{token: "secret"}}
      {:binary, bin} = ETF.encode(payload)
      decoded = :erlang.binary_to_term(bin)
      assert Map.has_key?(decoded, "op")
      assert Map.has_key?(decoded["d"], "token")
    end
  end

  describe "url_encoding/0" do
    test "returns \"etf\"" do
      assert ETF.url_encoding() == "etf"
    end
  end

  describe "normalize/1" do
    test "converts atom keys to strings" do
      assert ETF.normalize(%{foo: "bar"}) == %{"foo" => "bar"}
    end

    test "preserves string keys" do
      assert ETF.normalize(%{"foo" => "bar"}) == %{"foo" => "bar"}
    end

    test "handles empty maps" do
      assert ETF.normalize(%{}) == %{}
    end

    test "handles empty lists" do
      assert ETF.normalize([]) == []
    end

    test "converts integers from 2^48, the snowflakes, to strings" do
      assert ETF.normalize(281_474_976_710_656) == "281474976710656"
      assert ETF.normalize(159_985_870_458_322_944) == "159985870458322944"
    end

    test "keeps every other integer an integer, as JSON does" do
      # Seen on real payloads: a role colour, channel flags, a member limit, a millisecond version.
      term = %{
        color: 16_777_215,
        flags: 11_051_008,
        max_members: 25_000_000,
        version: 1_790_183_039_714
      }

      assert ETF.normalize(term) == %{
               "color" => 16_777_215,
               "flags" => 11_051_008,
               "max_members" => 25_000_000,
               "version" => 1_790_183_039_714
             }

      assert ETF.normalize(281_474_976_710_655) == 281_474_976_710_655
    end

    test "turns a permission bitfield into a string whatever its value" do
      assert ETF.normalize(%{allow: 1024, deny: 0}) == %{"allow" => "1024", "deny" => "0"}
    end

    test "gives the same result for a key EDA does not know" do
      assert ETF.normalize(%{eda_unknown_field_xyz: 1}) == %{"eda_unknown_field_xyz" => 1}
    end

    test "preserves negative integers" do
      assert ETF.normalize(-1) == -1
      assert ETF.normalize(-999_999_999) == -999_999_999
    end

    test "preserves zero" do
      assert ETF.normalize(0) == 0
    end

    test "recursively normalizes deep nesting" do
      input = %{a: %{b: %{c: [%{id: 123_456_789_012_345_678}]}}}

      assert ETF.normalize(input) == %{
               "a" => %{"b" => %{"c" => [%{"id" => "123456789012345678"}]}}
             }
    end

    test "converts atom values to strings" do
      assert ETF.normalize(:MESSAGE_CREATE) == "MESSAGE_CREATE"
      assert ETF.normalize(:READY) == "READY"
    end

    test "preserves binary strings" do
      assert ETF.normalize("hello") == "hello"
    end

    test "preserves floats" do
      assert ETF.normalize(3.14) == 3.14
    end

    test "handles integer map keys" do
      input = %{1 => "one", 2 => "two"}
      assert ETF.normalize(input) == %{"1" => "one", "2" => "two"}
    end
  end
end
