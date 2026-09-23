defmodule EDA.Event.ThreadCreate do
  @moduledoc """
  Sent when a thread is created, or the bot is added to a private thread. Delivers an `EDA.Channel`, not a struct of its own.

  The consumer receives `{:THREAD_CREATE, %EDA.Channel{}}`, with every field Discord sent — including
  what only a thread, a forum, a voice channel or a direct message has, in `thread`, `forum`,
  `voice` and `dm`. `thread.newly_created` tells a new thread from being added to an existing one, and `thread.member` is the bot's membership. This module only parses the payload.
  """

  @doc "Parses the `THREAD_CREATE` payload into an `EDA.Channel`."
  @spec from_raw(map()) :: EDA.Channel.t()
  def from_raw(raw) when is_map(raw), do: EDA.Channel.from_raw(raw)
end
