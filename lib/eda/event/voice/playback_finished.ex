defmodule EDA.Event.VoicePlaybackFinished do
  @moduledoc "Dispatched when voice playback finishes."

  use EDA.Event.Access

  defstruct [:guild_id]

  @type t :: %__MODULE__{
          guild_id: String.t() | nil
        }

  @doc "Converts a raw Discord payload into this event struct."
  @spec from_raw(map()) :: t()
  def from_raw(%__MODULE__{} = parsed), do: parsed

  def from_raw(raw) when is_map(raw) do
    %__MODULE__{
      guild_id: :maps.get("guild_id", raw, nil)
    }
  end
end
