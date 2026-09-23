defmodule EDA.Event.GuildScheduledEventUserAdd do
  @moduledoc "Dispatched when a user subscribes to a guild scheduled event."
  use EDA.Event.Access
  defstruct [:guild_scheduled_event_id, :user_id, :guild_id]

  @type t :: %__MODULE__{
          guild_scheduled_event_id: String.t() | nil,
          user_id: String.t() | nil,
          guild_id: String.t() | nil
        }
  @doc "Converts a raw Discord payload into this event struct."
  @spec from_raw(map()) :: t()
  def from_raw(%__MODULE__{} = parsed), do: parsed

  def from_raw(raw) when is_map(raw) do
    %__MODULE__{
      guild_scheduled_event_id: :maps.get("guild_scheduled_event_id", raw, nil),
      user_id: :maps.get("user_id", raw, nil),
      guild_id: :maps.get("guild_id", raw, nil)
    }
  end
end
