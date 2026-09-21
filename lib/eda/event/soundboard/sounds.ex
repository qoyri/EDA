defmodule EDA.Event.SoundboardSounds do
  @moduledoc """
  A guild's soundboard sounds, dispatched in answer to `EDA.SoundboardSound.request/1` — one
  event per guild requested.
  """
  use EDA.Event.Access

  defstruct [:guild_id, soundboard_sounds: []]

  @type t :: %__MODULE__{guild_id: String.t() | nil, soundboard_sounds: [EDA.SoundboardSound.t()]}

  @doc "Converts a raw Discord payload into this event struct."
  @spec from_raw(map()) :: t()
  def from_raw(raw) when is_map(raw) do
    %__MODULE__{
      guild_id: raw["guild_id"],
      soundboard_sounds: Enum.map(raw["soundboard_sounds"] || [], &EDA.SoundboardSound.from_raw/1)
    }
  end
end
