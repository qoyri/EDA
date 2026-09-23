defmodule EDA.Gateway.Encoding.JSONTest do
  use ExUnit.Case, async: true

  alias EDA.Gateway.Encoding.JSON

  describe "decode/1" do
    test "parses valid JSON into a map with string keys" do
      json = ~s({"op":10,"d":{"heartbeat_interval":41250}})
      assert %{"op" => 10, "d" => %{"heartbeat_interval" => 41_250}} = JSON.decode(json)
    end

    test "snowflakes remain as strings" do
      json = ~s({"id":"123456789012345678"})
      assert %{"id" => "123456789012345678"} = JSON.decode(json)
    end

    test "a long string does not keep the whole frame alive" do
      topic = String.duplicate("t", 200)
      frame = Jason.encode!(%{"topic" => topic, "padding" => String.duplicate("p", 50_000)})

      assert %{"topic" => ^topic} = decoded = JSON.decode(frame)
      assert :binary.referenced_byte_size(decoded["topic"]) == 200
    end

    test "raises on invalid JSON" do
      assert_raise Jason.DecodeError, fn ->
        JSON.decode("not json")
      end
    end
  end

  describe "encode/1" do
    test "returns {:text, iodata} tuple" do
      {:text, iodata} = JSON.encode(%{op: 1, d: nil})
      assert is_binary(iodata) or is_list(iodata)
    end

    test "roundtrips correctly" do
      payload = %{"op" => 1, "d" => 42}
      {:text, encoded} = JSON.encode(payload)
      assert JSON.decode(IO.iodata_to_binary(encoded)) == payload
    end
  end

  describe "url_encoding/0" do
    test "returns \"json\"" do
      assert JSON.url_encoding() == "json"
    end
  end
end
