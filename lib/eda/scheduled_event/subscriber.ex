defmodule EDA.ScheduledEvent.Subscriber do
  @moduledoc """
  A user interested in a scheduled event, with their guild `member` when it was asked for
  (`with_member: true`).
  """

  use EDA.Event.Access

  defstruct [:guild_scheduled_event_id, :user, :member]

  @type t :: %__MODULE__{
          guild_scheduled_event_id: String.t() | nil,
          user: EDA.User.t() | nil,
          member: EDA.Member.t() | nil
        }

  @doc false
  @spec from_raw(map()) :: t()
  def from_raw(raw) when is_map(raw) do
    %__MODULE__{
      guild_scheduled_event_id: raw["guild_scheduled_event_id"],
      user: raw["user"] && EDA.User.from_raw(raw["user"]),
      member: raw["member"] && EDA.Member.from_raw(raw["member"])
    }
  end
end
