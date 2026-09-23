defmodule EDA.Event.GuildStickersUpdate do
  @moduledoc "Dispatched when a guild's stickers are updated."
  use EDA.Event.Access

  defstruct [:guild_id, :stickers]

  @type t :: %__MODULE__{
          guild_id: String.t() | nil,
          stickers: [EDA.Sticker.t()] | nil
        }

  @doc "Converts a raw Discord payload into this event struct."
  @spec from_raw(map()) :: t()
  def from_raw(%__MODULE__{} = parsed), do: parsed

  def from_raw(raw) when is_map(raw) do
    stickers =
      (:maps.get("stickers", raw, nil) || [])
      |> Enum.map(&EDA.Sticker.from_raw/1)

    %__MODULE__{
      guild_id: :maps.get("guild_id", raw, nil),
      stickers: stickers
    }
  end
end
