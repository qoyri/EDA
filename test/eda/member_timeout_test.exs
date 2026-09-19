defmodule EDA.MemberTimeoutTest do
  use ExUnit.Case, async: true

  alias EDA.Member

  doctest EDA.Member, only: [time_out_end: 1, timed_out?: 1]

  defp iso(offset_seconds) do
    DateTime.utc_now()
    |> DateTime.add(offset_seconds, :second)
    |> DateTime.to_iso8601()
  end

  describe "time_out_end/1" do
    test "parses the ISO8601 timestamp Discord sends" do
      assert %DateTime{} =
               Member.time_out_end(%Member{communication_disabled_until: "2099-01-01T00:00:00Z"})
    end

    test "reads a raw member map, as the cache stores it" do
      assert %DateTime{} =
               Member.time_out_end(%{"communication_disabled_until" => "2099-01-01T00:00:00Z"})
    end

    test "nil when never timed out, or for an unrelated value" do
      assert Member.time_out_end(%Member{}) == nil
      assert Member.time_out_end(%{}) == nil
      assert Member.time_out_end(nil) == nil
    end

    test "a malformed timestamp gives nil rather than raising" do
      assert Member.time_out_end(%Member{communication_disabled_until: "not a date"}) == nil
    end

    test "still returns an expired timeout — Discord leaves the field populated" do
      past = iso(-3600)

      assert %DateTime{} = Member.time_out_end(%Member{communication_disabled_until: past})
    end
  end

  describe "timed_out?/1" do
    test "true only while the timeout is in the future" do
      assert Member.timed_out?(%Member{communication_disabled_until: iso(3600)})
    end

    test "false once it has expired — the distinction time_out_end/1 does not make" do
      refute Member.timed_out?(%Member{communication_disabled_until: iso(-1)})
      refute Member.timed_out?(%Member{communication_disabled_until: iso(-86_400)})
    end

    test "false when never timed out" do
      refute Member.timed_out?(%Member{})
      refute Member.timed_out?(%{})
    end

    test "works on a raw member map" do
      assert Member.timed_out?(%{"communication_disabled_until" => iso(3600)})
      refute Member.timed_out?(%{"communication_disabled_until" => iso(-1)})
    end
  end
end
