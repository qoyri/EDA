defmodule EDA.Event.GuildScheduledEventDelete do
  @moduledoc """
  Sent when a scheduled event is deleted. Delivers an `EDA.ScheduledEvent`, not a struct of its own.

  The consumer receives `{:GUILD_SCHEDULED_EVENT_DELETE, %EDA.ScheduledEvent{}}`, cover image and recurrence rule
  included. This module only parses the payload.
  """

  @doc "Parses the `GUILD_SCHEDULED_EVENT_DELETE` payload into an `EDA.ScheduledEvent`."
  @spec from_raw(map()) :: EDA.ScheduledEvent.t()
  def from_raw(raw) when is_map(raw), do: EDA.ScheduledEvent.from_raw(raw)
end
