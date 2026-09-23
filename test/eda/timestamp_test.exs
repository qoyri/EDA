defmodule EDA.TimestampTest do
  @moduledoc """
  `EDA.Timestamp.parse/1` reads Discord's two timestamp shapes by matching bytes, and must agree
  with `DateTime.from_iso8601/1` on everything: measured at 560 ns against 1500 for the shape
  with a fraction, 225 against 900 for the one without.
  """

  use ExUnit.Case, async: true

  doctest EDA.Timestamp

  alias EDA.Timestamp

  defp reference(iso) do
    case DateTime.from_iso8601(iso) do
      {:ok, dt, _} -> dt
      _ -> nil
    end
  end

  test "agrees with DateTime.from_iso8601/1 on both of Discord's shapes, across a year" do
    for day <- 0..365//7, hour <- [0, 9, 23], fraction <- ["", ".000000", ".123456", ".999999"] do
      date = Date.add(~D[2024-01-01], day)

      iso =
        "#{Date.to_iso8601(date)}T#{String.pad_leading("#{hour}", 2, "0")}:05:59#{fraction}+00:00"

      assert Timestamp.parse(iso) == reference(iso), iso
    end
  end

  test "agrees on the shapes it leaves to the slow path" do
    for iso <- [
          "2026-09-23T10:15:30Z",
          "2026-09-23T10:15:30.123Z",
          "2026-09-23T12:15:30+02:00",
          "2026-09-23T10:15:30.12345+00:00"
        ] do
      assert Timestamp.parse(iso) == reference(iso), iso
    end
  end

  test "refuses what is not a real date, like DateTime.from_iso8601/1" do
    for iso <- [
          "2026-02-30T10:00:00+00:00",
          "2026-13-01T10:00:00+00:00",
          "2026-09-23T24:00:00+00:00",
          "2026-09-23T10:60:00+00:00",
          "2026-09-2xT10:00:00+00:00",
          "",
          "2026-09-23"
        ] do
      assert Timestamp.parse(iso) == nil, iso
    end
  end

  test "a leap day is accepted, and only in a leap year" do
    assert %DateTime{month: 2, day: 29} = Timestamp.parse("2024-02-29T00:00:00+00:00")
    assert Timestamp.parse("2025-02-29T00:00:00+00:00") == nil
  end

  test "passes a DateTime through, and nil and other terms give nil" do
    assert Timestamp.parse(~U[2026-01-01 00:00:00Z]) == ~U[2026-01-01 00:00:00Z]
    assert Timestamp.parse(nil) == nil
    assert Timestamp.parse(42) == nil
  end

  test "Unix times, in seconds or milliseconds, as integers or strings" do
    assert Timestamp.from_unix("1790000000") == ~U[2026-09-21 14:13:20Z]
    assert Timestamp.from_unix_ms(1_790_000_000_000) == ~U[2026-09-21 14:13:20.000Z]
    assert Timestamp.from_unix(nil) == nil
    assert Timestamp.from_unix("soon") == nil
  end
end
