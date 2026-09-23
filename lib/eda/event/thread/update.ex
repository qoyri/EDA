defmodule EDA.Event.ThreadUpdate do
  @moduledoc """
  Sent when a thread is updated. Delivers an `EDA.Channel`, not a struct of its own.

  The consumer receives `{:THREAD_UPDATE, %EDA.Channel{}}`, with every field Discord sent — including
  what only a thread, a forum, a voice channel or a direct message has, in `thread`, `forum`,
  `voice` and `dm`. This module only parses the payload.
  """

  @doc "Parses the `THREAD_UPDATE` payload into an `EDA.Channel`."
  @spec from_raw(map()) :: EDA.Channel.t()
  def from_raw(raw) when is_map(raw), do: EDA.Channel.from_raw(raw)
end
