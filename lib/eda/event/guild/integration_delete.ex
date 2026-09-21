defmodule EDA.Event.IntegrationDelete do
  @moduledoc "Dispatched when an integration is removed from a guild. Needs the `:guild_integrations` intent."
  use EDA.Event.Access

  defstruct [:id, :guild_id, :application_id]

  @type t :: %__MODULE__{
          id: String.t() | nil,
          guild_id: String.t() | nil,
          application_id: String.t() | nil
        }

  @doc "Converts a raw Discord payload into this event struct."
  @spec from_raw(map()) :: t()
  def from_raw(raw) when is_map(raw),
    do: %__MODULE__{
      id: raw["id"],
      guild_id: raw["guild_id"],
      application_id: raw["application_id"]
    }
end
