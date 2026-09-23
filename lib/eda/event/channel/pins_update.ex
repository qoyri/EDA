defmodule EDA.Event.ChannelPinsUpdate do
  @moduledoc "Dispatched when a channel's pins are updated."
  use EDA.Event.Access
  defstruct [:guild_id, :channel_id, :last_pin_timestamp]

  @type t :: %__MODULE__{
          guild_id: String.t() | nil,
          channel_id: String.t() | nil,
          last_pin_timestamp: DateTime.t() | nil
        }
  @doc "Converts a raw Discord payload into this event struct."
  @spec from_raw(map()) :: t()
  def from_raw(raw) when is_map(raw) do
    %__MODULE__{
      guild_id: raw["guild_id"],
      channel_id: raw["channel_id"],
      last_pin_timestamp: EDA.Timestamp.parse(raw["last_pin_timestamp"])
    }
  end
end
