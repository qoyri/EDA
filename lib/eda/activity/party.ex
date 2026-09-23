defmodule EDA.Activity.Party do
  @moduledoc """
  The party of an activity: its `id`, and its `size` as `[current, max]`.
  """

  use EDA.Event.Access

  defstruct [:id, :size]

  @type t :: %__MODULE__{
          id: String.t() | nil,
          size: [non_neg_integer()] | nil
        }

  @doc false
  @spec from_raw(map() | nil) :: t() | nil
  def from_raw(nil), do: nil
  def from_raw(raw) when is_map(raw), do: %__MODULE__{id: raw["id"], size: raw["size"]}
end
