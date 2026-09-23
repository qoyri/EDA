defmodule EDA.Event.MessageDeleteBulk do
  @moduledoc "Dispatched when multiple messages are deleted at once."
  use EDA.Event.Access
  defstruct [:ids, :channel_id, :guild_id]

  @type t :: %__MODULE__{
          ids: [String.t()] | nil,
          channel_id: String.t() | nil,
          guild_id: String.t() | nil
        }
  @doc "Converts a raw Discord payload into this event struct."
  @spec from_raw(map()) :: t()
  def from_raw(%__MODULE__{} = parsed), do: parsed

  def from_raw(raw) when is_map(raw) do
    %__MODULE__{
      ids: :maps.get("ids", raw, nil),
      channel_id: :maps.get("channel_id", raw, nil),
      guild_id: :maps.get("guild_id", raw, nil)
    }
  end
end
