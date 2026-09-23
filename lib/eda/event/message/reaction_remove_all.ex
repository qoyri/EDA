defmodule EDA.Event.MessageReactionRemoveAll do
  @moduledoc "Dispatched when all reactions are removed from a message."
  use EDA.Event.Access
  defstruct [:channel_id, :message_id, :guild_id]

  @type t :: %__MODULE__{
          channel_id: String.t() | nil,
          message_id: String.t() | nil,
          guild_id: String.t() | nil
        }
  @doc "Converts a raw Discord payload into this event struct."
  @spec from_raw(map()) :: t()
  def from_raw(%__MODULE__{} = parsed), do: parsed

  def from_raw(raw) when is_map(raw) do
    %__MODULE__{
      channel_id: :maps.get("channel_id", raw, nil),
      message_id: :maps.get("message_id", raw, nil),
      guild_id: :maps.get("guild_id", raw, nil)
    }
  end
end
