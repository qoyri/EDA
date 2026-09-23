defmodule EDA.Activity.Timestamps do
  @moduledoc """
  When an activity started, and when it will end: a game's elapsed time counts from `start`, a
  song's remaining time runs to `end`. Either may be `nil`.
  """

  use EDA.Event.Access

  defstruct [:start, :end]

  @type t :: %__MODULE__{start: DateTime.t() | nil, end: DateTime.t() | nil}

  @doc false
  @spec from_raw(map() | nil) :: t() | nil
  def from_raw(nil), do: nil

  def from_raw(raw) when is_map(raw) do
    %__MODULE__{
      start: EDA.Timestamp.from_unix_ms(raw["start"]),
      end: EDA.Timestamp.from_unix_ms(raw["end"])
    }
  end
end
