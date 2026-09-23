defmodule EDA.Event.WebhooksUpdate do
  @moduledoc "Dispatched when a guild channel's webhook is created, updated, or deleted."
  use EDA.Event.Access
  defstruct [:guild_id, :channel_id]
  @type t :: %__MODULE__{guild_id: String.t() | nil, channel_id: String.t() | nil}
  @doc "Converts a raw Discord payload into this event struct."
  @spec from_raw(map()) :: t()
  def from_raw(%__MODULE__{} = parsed), do: parsed

  def from_raw(raw) when is_map(raw) do
    %__MODULE__{
      guild_id: :maps.get("guild_id", raw, nil),
      channel_id: :maps.get("channel_id", raw, nil)
    }
  end
end
