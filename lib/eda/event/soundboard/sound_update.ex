defmodule EDA.Event.GuildSoundboardSoundUpdate do
  @moduledoc """
  Sent when a guild soundboard sound is modified. Needs the `:guild_expressions` intent. Delivers
  an `EDA.SoundboardSound`, not a struct of its own.

  The consumer receives `{:GUILD_SOUNDBOARD_SOUND_UPDATE, %EDA.SoundboardSound{}}`. This module
  only parses the payload.
  """

  @doc "Parses the `GUILD_SOUNDBOARD_SOUND_UPDATE` payload into an `EDA.SoundboardSound`."
  @spec from_raw(map()) :: EDA.SoundboardSound.t()
  def from_raw(raw) when is_map(raw), do: EDA.SoundboardSound.from_raw(raw)
end
