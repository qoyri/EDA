defmodule EDA.Message.Activity do
  @moduledoc """
  A Rich Presence invite sent in chat: to `:join`, `:spectate` or `:listen` along, a
  `:join_request`, or a `:stream_request`, for the party `party_id`.
  """

  use EDA.Event.Access

  defstruct [:type, :party_id]

  @type t :: %__MODULE__{
          type: :join | :spectate | :listen | :join_request | :stream_request | integer() | nil,
          party_id: String.t() | nil
        }

  @types %{1 => :join, 2 => :spectate, 3 => :listen, 5 => :join_request, 6 => :stream_request}

  @doc false
  @spec from_raw(map() | nil) :: t() | nil
  def from_raw(nil), do: nil

  def from_raw(raw) when is_map(raw),
    do: %__MODULE__{type: EDA.Enum.name(@types, raw["type"]), party_id: raw["party_id"]}
end
