defmodule EDA.Event.IntegrationCreate do
  @moduledoc "Dispatched when an integration is added to a guild. Needs the `:guild_integrations` intent."
  use EDA.Event.Access

  defstruct [:guild_id, :integration]

  @type t :: %__MODULE__{guild_id: String.t() | nil, integration: EDA.Integration.t()}

  @doc "Converts a raw Discord payload into this event struct."
  @spec from_raw(map()) :: t()
  def from_raw(raw) when is_map(raw),
    do: %__MODULE__{guild_id: raw["guild_id"], integration: EDA.Integration.from_raw(raw)}
end
