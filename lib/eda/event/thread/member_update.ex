defmodule EDA.Event.ThreadMemberUpdate do
  @moduledoc "Dispatched when the thread member object for the current user is updated."
  use EDA.Event.Access
  defstruct [:id, :guild_id, :user_id, :join_timestamp, :flags]

  @type t :: %__MODULE__{
          id: String.t() | nil,
          guild_id: String.t() | nil,
          user_id: String.t() | nil,
          join_timestamp: DateTime.t() | nil,
          flags: integer() | nil
        }
  @doc "Converts a raw Discord payload into this event struct."
  @spec from_raw(map()) :: t()
  def from_raw(raw) when is_map(raw) do
    %__MODULE__{
      id: raw["id"],
      guild_id: raw["guild_id"],
      user_id: raw["user_id"],
      join_timestamp: EDA.Timestamp.parse(raw["join_timestamp"]),
      flags: raw["flags"]
    }
  end
end
