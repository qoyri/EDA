defmodule EDA.Event.VoiceStateUpdate do
  @moduledoc """
  Sent when a user joins, leaves or moves between voice channels, or mutes, deafens or streams.
  Delivers an `EDA.VoiceState`, not a struct of its own.

  The consumer receives `{:VOICE_STATE_UPDATE, %EDA.VoiceState{}}`. This module only parses the
  payload.
  """

  @doc "Parses the `VOICE_STATE_UPDATE` payload into an `EDA.VoiceState`."
  @spec from_raw(map()) :: EDA.VoiceState.t()
  def from_raw(raw) when is_map(raw), do: EDA.VoiceState.from_raw(raw)
end
