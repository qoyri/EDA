defmodule EDA.Event.VoiceChannelStatusUpdate do
  @moduledoc "Dispatched when a voice channel's status is set or cleared."
  use EDA.Event.Access
  defstruct [:channel_id, :guild_id, :status]

  @type t :: %__MODULE__{
          channel_id: String.t() | nil,
          guild_id: String.t() | nil,
          status: String.t() | nil
        }

  @doc "Converts a raw Discord payload into this event struct."
  @spec from_raw(map()) :: t()
  def from_raw(raw) when is_map(raw) do
    %__MODULE__{
      channel_id: raw["id"],
      guild_id: raw["guild_id"],
      status: raw["status"]
    }
  end
end
