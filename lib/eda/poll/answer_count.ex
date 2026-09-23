defmodule EDA.Poll.AnswerCount do
  @moduledoc """
  Represents the vote count for a specific poll answer.

  Provides typed access to vote counts instead of raw maps.

  ## Example

      %EDA.Poll.AnswerCount{
        id: 1,
        count: 42,
        me_voted: false
      }
  """

  use EDA.Event.Access

  defstruct [:id, :count, :me_voted]

  @type t :: %__MODULE__{
          id: integer() | nil,
          count: integer() | nil,
          me_voted: boolean() | nil
        }

  @doc """
  Parses an answer count from a raw Discord API map.

  ## Examples

      iex> EDA.Poll.AnswerCount.from_raw(%{"id" => 1, "count" => 42, "me_voted" => false})
      %EDA.Poll.AnswerCount{id: 1, count: 42, me_voted: false}
  """
  @spec from_raw(map()) :: t()
  def from_raw(raw) when is_map(raw) do
    %__MODULE__{
      id: raw["id"],
      count: raw["count"],
      me_voted: raw["me_voted"]
    }
  end
end
