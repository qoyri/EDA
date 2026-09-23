defmodule EDA.Event.GuildEmojisUpdate do
  @moduledoc "Dispatched when a guild's emojis are updated."
  use EDA.Event.Access

  defstruct [:guild_id, :emojis]

  @type t :: %__MODULE__{
          guild_id: String.t() | nil,
          emojis: [EDA.Emoji.t()] | nil
        }

  @doc "Converts a raw Discord payload into this event struct."
  @spec from_raw(map()) :: t()
  def from_raw(%__MODULE__{} = parsed), do: parsed

  def from_raw(raw) when is_map(raw) do
    emojis =
      (:maps.get("emojis", raw, nil) || [])
      |> Enum.map(&EDA.Emoji.from_raw/1)

    %__MODULE__{
      guild_id: :maps.get("guild_id", raw, nil),
      emojis: emojis
    }
  end
end
