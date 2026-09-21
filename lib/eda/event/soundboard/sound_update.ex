defmodule EDA.Event.GuildSoundboardSoundUpdate do
  @moduledoc "Dispatched when a guild soundboard sound is modified. Needs the `:guild_expressions` intent."
  use EDA.Event.Access

  defstruct [:guild_id, :sound]

  @type t :: %__MODULE__{guild_id: String.t() | nil, sound: EDA.SoundboardSound.t()}

  @doc "Converts a raw Discord payload into this event struct."
  @spec from_raw(map()) :: t()
  def from_raw(raw) when is_map(raw) do
    %__MODULE__{guild_id: raw["guild_id"], sound: EDA.SoundboardSound.from_raw(raw)}
  end
end
