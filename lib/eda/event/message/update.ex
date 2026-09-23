defmodule EDA.Event.MessageUpdate do
  @moduledoc """
  `MESSAGE_UPDATE` delivers an `EDA.Message`, not a struct of its own.

  The consumer receives `{:MESSAGE_UPDATE, %EDA.Message{}}`, with every field of the message and
  the ones the gateway adds (`guild_id`, `member`, `channel_type`), so the message can be passed
  straight to `EDA.Message.reply/2` and the other message functions. This module only parses
  the payload. Discord sends the whole message on an edit too, with `tts` always false.
  """

  @doc "Parses the `MESSAGE_UPDATE` payload into an `EDA.Message`."
  @spec from_raw(map()) :: EDA.Message.t()
  def from_raw(raw) when is_map(raw), do: EDA.Message.from_raw(raw)
end
