defmodule EDA.Event.VoiceAudio do
  @moduledoc "Dispatched when voice audio data is received."

  use EDA.Event.Access

  defstruct [:guild_id, :user_id, :ssrc, :opus]

  @type t :: %__MODULE__{
          guild_id: String.t() | nil,
          user_id: String.t() | nil,
          ssrc: integer() | nil,
          opus: binary() | nil
        }

  @doc "Converts a raw Discord payload into this event struct."
  @spec from_raw(map()) :: t()
  def from_raw(%__MODULE__{} = parsed), do: parsed

  def from_raw(raw) when is_map(raw) do
    %__MODULE__{
      guild_id: :maps.get("guild_id", raw, nil),
      user_id: :maps.get("user_id", raw, nil),
      ssrc: :maps.get("ssrc", raw, nil),
      opus: :maps.get("opus", raw, nil)
    }
  end
end
