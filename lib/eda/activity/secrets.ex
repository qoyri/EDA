defmodule EDA.Activity.Secrets do
  @moduledoc """
  The secrets a game shares to let others join or spectate an activity, or match into it.
  """

  use EDA.Event.Access

  defstruct [:join, :spectate, :match]

  @type t :: %__MODULE__{
          join: String.t() | nil,
          spectate: String.t() | nil,
          match: String.t() | nil
        }

  @doc false
  @spec from_raw(map() | nil) :: t() | nil
  def from_raw(nil), do: nil

  def from_raw(raw) when is_map(raw),
    do: %__MODULE__{join: raw["join"], spectate: raw["spectate"], match: raw["match"]}
end
