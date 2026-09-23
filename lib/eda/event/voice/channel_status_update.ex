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
  def from_raw(%__MODULE__{} = parsed), do: parsed

  def from_raw(raw) when is_map(raw) do
    %__MODULE__{
      channel_id: :maps.get("id", raw, nil),
      guild_id: :maps.get("guild_id", raw, nil),
      status: :maps.get("status", raw, nil)
    }
  end
end
