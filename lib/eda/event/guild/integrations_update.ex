defmodule EDA.Event.GuildIntegrationsUpdate do
  @moduledoc "Dispatched when a guild's integrations change. Carries only the guild id."
  use EDA.Event.Access

  defstruct [:guild_id]

  @type t :: %__MODULE__{guild_id: String.t() | nil}

  @doc "Converts a raw Discord payload into this event struct."
  @spec from_raw(map()) :: t()
  def from_raw(raw) when is_map(raw), do: %__MODULE__{guild_id: raw["guild_id"]}
end
