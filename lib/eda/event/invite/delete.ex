defmodule EDA.Event.InviteDelete do
  @moduledoc "Dispatched when an invite is deleted."
  use EDA.Event.Access
  defstruct [:channel_id, :guild_id, :code]

  @type t :: %__MODULE__{
          channel_id: String.t() | nil,
          guild_id: String.t() | nil,
          code: String.t() | nil
        }
  @doc "Converts a raw Discord payload into this event struct."
  @spec from_raw(map()) :: t()
  def from_raw(%__MODULE__{} = parsed), do: parsed

  def from_raw(raw) when is_map(raw) do
    %__MODULE__{
      channel_id: :maps.get("channel_id", raw, nil),
      guild_id: :maps.get("guild_id", raw, nil),
      code: :maps.get("code", raw, nil)
    }
  end
end
