defmodule EDA.Timestamp do
  @moduledoc """
  Reads the timestamps Discord sends into `DateTime` structs.

  Every date EDA parses — a message's `timestamp`, a member's `joined_at`, an invite's
  `expires_at`… — goes through `parse/1`, which is also there for a date in a raw payload:

      EDA.Timestamp.parse(raw["joined_at"])

  Discord writes them in two shapes, always in UTC, seen on every date of a real bot:
  `2026-09-23T10:15:30.123456+00:00` and `2026-09-23T10:15:30+00:00`. Those are read by matching
  the bytes directly, several times faster than `DateTime.from_iso8601/1`, which parsing every
  event would otherwise pay for each date. Anything else still goes through
  `DateTime.from_iso8601/1`, so no valid timestamp is refused.
  """

  @doc """
  Parses a Discord timestamp. Returns `nil` for `nil` or anything that is not a valid timestamp,
  and passes a `DateTime` through.

      iex> EDA.Timestamp.parse("2026-09-23T10:15:30.123456+00:00")
      ~U[2026-09-23 10:15:30.123456Z]

      iex> EDA.Timestamp.parse("2026-09-23T10:15:30+00:00")
      ~U[2026-09-23 10:15:30Z]

      iex> EDA.Timestamp.parse("2026-09-23T12:15:30+02:00")
      ~U[2026-09-23 10:15:30Z]

      iex> EDA.Timestamp.parse("not a date")
      nil
  """
  @spec parse(String.t() | DateTime.t() | nil) :: DateTime.t() | nil
  def parse(nil), do: nil
  def parse(%DateTime{} = datetime), do: datetime

  # The digits are read straight from the bytes: no intermediate string, list or integer parse.
  def parse(
        <<y1, y2, y3, y4, ?-, mo1, mo2, ?-, d1, d2, ?T, h1, h2, ?:, mi1, mi2, ?:, s1, s2,
          rest::binary>> = iso
      ) do
    with year when is_integer(year) <- num4(y1, y2, y3, y4),
         month when is_integer(month) <- num2(mo1, mo2),
         day when is_integer(day) <- num2(d1, d2),
         hour when is_integer(hour) <- num2(h1, h2),
         minute when is_integer(minute) <- num2(mi1, mi2),
         second when is_integer(second) <- num2(s1, s2),
         {:ok, microsecond} <- fraction(rest),
         %DateTime{} = datetime <- build(year, month, day, hour, minute, second, microsecond) do
      datetime
    else
      _ -> slow(iso)
    end
  end

  def parse(iso) when is_binary(iso), do: slow(iso)
  def parse(_other), do: nil

  @doc """
  Converts a Unix timestamp in seconds, as Discord sends in a few places (`TYPING_START`, voice
  channel start times), to a `DateTime`. Accepts the integer or its string form.

      iex> EDA.Timestamp.from_unix(1_790_000_000)
      ~U[2026-09-21 14:13:20Z]
  """
  @spec from_unix(integer() | String.t() | nil) :: DateTime.t() | nil
  def from_unix(seconds), do: unix(seconds, :second)

  @doc """
  Converts a Unix timestamp in milliseconds, as activities carry them, to a `DateTime`.

      iex> EDA.Timestamp.from_unix_ms(1_790_000_000_123)
      ~U[2026-09-21 14:13:20.123Z]
  """
  @spec from_unix_ms(integer() | String.t() | nil) :: DateTime.t() | nil
  def from_unix_ms(milliseconds), do: unix(milliseconds, :millisecond)

  defp unix(nil, _unit), do: nil
  defp unix(%DateTime{} = datetime, _unit), do: datetime

  defp unix(value, unit) when is_integer(value) do
    case DateTime.from_unix(value, unit) do
      {:ok, datetime} -> datetime
      {:error, _} -> nil
    end
  end

  defp unix(value, unit) when is_binary(value) do
    case Integer.parse(value) do
      {int, ""} -> unix(int, unit)
      _ -> nil
    end
  end

  defp unix(_value, _unit), do: nil

  defguardp digit(c) when c in ?0..?9

  defp num2(a, b) when digit(a) and digit(b), do: (a - ?0) * 10 + (b - ?0)
  defp num2(_a, _b), do: nil

  defp num4(a, b, c, d) when digit(a) and digit(b) and digit(c) and digit(d),
    do: (a - ?0) * 1000 + (b - ?0) * 100 + (c - ?0) * 10 + (d - ?0)

  defp num4(_a, _b, _c, _d), do: nil

  # The two shapes Discord uses; anything else goes the slow way.
  defp fraction(<<?., a, b, c, d, e, f, "+00:00">>) do
    with hi when is_integer(hi) <- num4(a, b, c, d),
         lo when is_integer(lo) <- num2(e, f) do
      {:ok, {hi * 100 + lo, 6}}
    else
      _ -> :error
    end
  end

  defp fraction("+00:00"), do: {:ok, {0, 0}}
  defp fraction(_rest), do: :error

  # Hours past 23 and the like are left to the slow path, which refuses them; the date is checked
  # for its month length.
  defp build(y, mo, d, h, mi, s, microsecond)
       when mo in 1..12 and d >= 1 and h <= 23 and mi <= 59 and s <= 59 do
    if d <= Calendar.ISO.days_in_month(y, mo) do
      %DateTime{
        year: y,
        month: mo,
        day: d,
        hour: h,
        minute: mi,
        second: s,
        microsecond: microsecond,
        time_zone: "Etc/UTC",
        zone_abbr: "UTC",
        utc_offset: 0,
        std_offset: 0,
        calendar: Calendar.ISO
      }
    end
  end

  defp build(_y, _mo, _d, _h, _mi, _s, _microsecond), do: nil

  defp slow(iso) do
    case DateTime.from_iso8601(iso) do
      {:ok, datetime, _offset} -> datetime
      {:error, _} -> nil
    end
  end
end
