defmodule EDA.Event.GuildSoundboardSoundDelete do
  @moduledoc "Dispatched when a guild soundboard sound is deleted. Needs the `:guild_expressions` intent."
  use EDA.Event.Access

  defstruct [:guild_id, :sound_id]

  @type t :: %__MODULE__{guild_id: String.t() | nil, sound_id: String.t() | nil}

  @doc "Converts a raw Discord payload into this event struct."
  @spec from_raw(map()) :: t()
  def from_raw(%__MODULE__{} = parsed), do: parsed

  def from_raw(raw) when is_map(raw) do
    %__MODULE__{
      guild_id: :maps.get("guild_id", raw, nil),
      sound_id: :maps.get("sound_id", raw, nil)
    }
  end
end
