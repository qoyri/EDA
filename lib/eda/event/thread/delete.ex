defmodule EDA.Event.ThreadDelete do
  @moduledoc """
  Sent when a thread is deleted. Delivers an `EDA.Channel`, not a struct of its own.

  The consumer receives `{:THREAD_DELETE, %EDA.Channel{}}`, with every field Discord sent — including
  what only a thread, a forum, a voice channel or a direct message has, in `thread`, `forum`,
  `voice` and `dm`. Discord sends only `id`, `guild_id`, `parent_id` and `type`; the other fields are `nil`. This module only parses the payload.
  """

  @doc "Parses the `THREAD_DELETE` payload into an `EDA.Channel`."
  @spec from_raw(map()) :: EDA.Channel.t()
  def from_raw(raw) when is_map(raw), do: EDA.Channel.from_raw(raw)
end
