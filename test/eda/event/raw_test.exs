defmodule EDA.Event.RawTest do
  use ExUnit.Case, async: true

  alias EDA.Event.Raw

  describe "from_raw/2" do
    test "stores event_type and the payload as Discord sent it" do
      raw = Raw.from_raw("SOME_EVENT", %{"key" => "value", "count" => 5})
      assert raw.event_type == "SOME_EVENT"
      assert raw.data == %{"key" => "value", "count" => 5}
      assert raw["data"]["key"] == "value"
    end

    test "creates no atom from the payload's keys" do
      key = "never_seen_key_#{System.unique_integer([:positive])}"
      Raw.from_raw("SOME_EVENT", %{key => 1})
      assert_raise ArgumentError, fn -> String.to_existing_atom(key) end
    end

    test "handles nil data" do
      raw = Raw.from_raw("EMPTY_EVENT", nil)
      assert raw.event_type == "EMPTY_EVENT"
      assert raw.data == nil
    end

    test "supports Access with string keys" do
      raw = Raw.from_raw("TEST", %{"x" => 1})
      assert raw["event_type"] == "TEST"
    end

    test "supports Access with atom keys" do
      raw = Raw.from_raw("TEST", %{"x" => 1})
      assert raw[:event_type] == "TEST"
    end
  end
end
