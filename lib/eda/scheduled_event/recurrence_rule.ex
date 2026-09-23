defmodule EDA.ScheduledEvent.RecurrenceRule do
  @moduledoc """
  How a scheduled event repeats.

  `frequency` is `:yearly`, `:monthly`, `:weekly` or `:daily`, every `interval` of them. The
  days are named: `by_weekday` lists `:monday`…`:sunday`, `by_n_weekday` holds `{n, day}` for
  "the n-th day of the month" (`{1, :friday}`: the first Friday), and `by_month` lists
  `:january`…`:december`. `start` and `end` are `DateTime`s.

  Discord sets `end`, `by_year_day` and `count` itself; the others are what an event is created
  with. The struct encodes as Discord takes it, so it can be sent as it is:

      rule = %EDA.ScheduledEvent.RecurrenceRule{
        start: ~U[2026-10-02 18:00:00Z],
        frequency: :weekly,
        interval: 1,
        by_weekday: [:friday]
      }

      EDA.API.ScheduledEvent.create(guild_id, %{name: "Game night", recurrence_rule: rule, ...})
  """

  use EDA.Event.Access

  defstruct [
    :start,
    :end,
    :frequency,
    :interval,
    :by_weekday,
    :by_n_weekday,
    :by_month,
    :by_month_day,
    :by_year_day,
    :count
  ]

  @type weekday :: :monday | :tuesday | :wednesday | :thursday | :friday | :saturday | :sunday
  @type month ::
          :january
          | :february
          | :march
          | :april
          | :may
          | :june
          | :july
          | :august
          | :september
          | :october
          | :november
          | :december

  @type t :: %__MODULE__{
          start: DateTime.t() | nil,
          end: DateTime.t() | nil,
          frequency: :yearly | :monthly | :weekly | :daily | integer() | nil,
          interval: pos_integer() | nil,
          by_weekday: [weekday() | integer()] | nil,
          by_n_weekday: [{1..5, weekday() | integer()}] | nil,
          by_month: [month() | integer()] | nil,
          by_month_day: [1..31] | nil,
          by_year_day: [1..366] | nil,
          count: pos_integer() | nil
        }

  @frequencies %{0 => :yearly, 1 => :monthly, 2 => :weekly, 3 => :daily}

  @weekdays ~w(monday tuesday wednesday thursday friday saturday sunday)a
            |> Enum.with_index()
            |> Map.new(fn {day, i} -> {i, day} end)

  @months ~w(january february march april may june july august september october november december)a
          |> Enum.with_index(1)
          |> Map.new(fn {month, i} -> {i, month} end)

  @doc """
  A recurrence rule as Discord sends it.

      iex> rule = EDA.ScheduledEvent.RecurrenceRule.from_raw(%{
      ...>   "start" => "2026-10-02T18:00:00+00:00",
      ...>   "frequency" => 1,
      ...>   "interval" => 1,
      ...>   "by_n_weekday" => [%{"n" => 1, "day" => 4}]
      ...> })
      iex> {rule.frequency, rule.by_n_weekday, rule.start}
      {:monthly, [{1, :friday}], ~U[2026-10-02 18:00:00Z]}
  """
  @spec from_raw(map() | nil) :: t() | nil
  def from_raw(nil), do: nil

  def from_raw(raw) when is_map(raw) do
    %__MODULE__{
      start: EDA.Timestamp.parse(raw["start"]),
      end: EDA.Timestamp.parse(raw["end"]),
      frequency: EDA.Enum.name(@frequencies, raw["frequency"]),
      interval: raw["interval"],
      by_weekday: names(raw["by_weekday"], @weekdays),
      by_n_weekday:
        raw["by_n_weekday"] &&
          Enum.map(raw["by_n_weekday"], &{&1["n"], EDA.Enum.name(@weekdays, &1["day"])}),
      by_month: names(raw["by_month"], @months),
      by_month_day: raw["by_month_day"],
      by_year_day: raw["by_year_day"],
      count: raw["count"]
    }
  end

  @doc """
  The rule as the map Discord takes, leaving out what is not set.

      iex> EDA.ScheduledEvent.RecurrenceRule.to_raw(%EDA.ScheduledEvent.RecurrenceRule{
      ...>   start: ~U[2026-10-02 18:00:00Z], frequency: :weekly, interval: 1, by_weekday: [:friday]
      ...> })
      %{start: "2026-10-02T18:00:00Z", frequency: 2, interval: 1, by_weekday: [4]}
  """
  @spec to_raw(t()) :: map()
  def to_raw(%__MODULE__{} = rule) do
    %{
      start: rule.start && DateTime.to_iso8601(rule.start),
      end: rule.end && DateTime.to_iso8601(rule.end),
      frequency: rule.frequency && EDA.Enum.value!(@frequencies, rule.frequency, "frequency"),
      interval: rule.interval,
      by_weekday: values(rule.by_weekday, @weekdays, "weekday"),
      by_n_weekday:
        rule.by_n_weekday &&
          Enum.map(rule.by_n_weekday, fn {n, day} ->
            %{n: n, day: EDA.Enum.value!(@weekdays, day, "weekday")}
          end),
      by_month: values(rule.by_month, @months, "month"),
      by_month_day: rule.by_month_day,
      by_year_day: rule.by_year_day,
      count: rule.count
    }
    |> Map.reject(fn {_k, v} -> is_nil(v) end)
  end

  defp names(nil, _table), do: nil
  defp names(list, table), do: Enum.map(list, &EDA.Enum.name(table, &1))

  defp values(nil, _table, _what), do: nil
  defp values(list, table, what), do: Enum.map(list, &EDA.Enum.value!(table, &1, what))
end

defimpl Jason.Encoder, for: EDA.ScheduledEvent.RecurrenceRule do
  def encode(rule, opts),
    do: rule |> EDA.ScheduledEvent.RecurrenceRule.to_raw() |> Jason.Encode.map(opts)
end
