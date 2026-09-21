defmodule EDA.Event.VoiceChannelStartTimeUpdate do
  @moduledoc """
  Dispatched when a voice channel's session start time changes: someone joined an empty channel,
  or the last person left (`voice_start_time: nil`).
  """
  use EDA.Event.Access

  defstruct [:channel_id, :guild_id, :voice_start_time]

  @type t :: %__MODULE__{
          channel_id: String.t() | nil,
          guild_id: String.t() | nil,
          voice_start_time: DateTime.t() | nil
        }

  @doc "Converts a raw Discord payload into this event struct."
  @spec from_raw(map()) :: t()
  def from_raw(raw) when is_map(raw) do
    %__MODULE__{
      channel_id: raw["id"],
      guild_id: raw["guild_id"],
      voice_start_time: EDA.Event.ChannelInfo.unix_time(raw["voice_start_time"])
    }
  end
end
