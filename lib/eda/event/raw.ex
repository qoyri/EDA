defmodule EDA.Event.Raw do
  @moduledoc """
  Fallback for a gateway event EDA does not type yet.

  `data` is the payload exactly as Discord sent it, string keys included — as every other raw
  Discord object is. The consumer still receives it under the event's own name, so a bot can
  handle an event Discord has just added before EDA types it:

      def handle_event({:SOME_NEW_EVENT, %EDA.Event.Raw{data: data}}), do: data["guild_id"]
  """

  use EDA.Event.Access

  defstruct [:event_type, :data]

  @type t :: %__MODULE__{
          event_type: String.t(),
          data: map() | nil
        }

  @doc "Wraps an event EDA does not type, keeping its payload as sent."
  @spec from_raw(String.t(), map() | nil) :: t()
  def from_raw(event_type, data), do: %__MODULE__{event_type: event_type, data: data}
end
