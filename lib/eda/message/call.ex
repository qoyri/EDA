defmodule EDA.Message.Call do
  @moduledoc """
  The call a `:call` message records, in a DM: the ids of the users who took part, and when it
  ended, `nil` while it goes on.
  """

  use EDA.Event.Access

  defstruct [:participants, :ended_timestamp]

  @type t :: %__MODULE__{
          participants: [String.t()] | nil,
          ended_timestamp: DateTime.t() | nil
        }

  @doc false
  @spec from_raw(map() | nil) :: t() | nil
  def from_raw(nil), do: nil

  def from_raw(raw) when is_map(raw) do
    %__MODULE__{
      participants: raw["participants"],
      ended_timestamp: EDA.Timestamp.parse(raw["ended_timestamp"])
    }
  end
end
