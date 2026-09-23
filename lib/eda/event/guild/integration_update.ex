defmodule EDA.Event.IntegrationUpdate do
  @moduledoc """
  Sent when an integration changes. Needs the `:guild_integrations` intent. Delivers an
  `EDA.Integration`, not a struct of its own.

  The consumer receives `{:INTEGRATION_UPDATE, %EDA.Integration{}}`. This module only parses the
  payload.
  """

  @doc "Parses the `INTEGRATION_UPDATE` payload into an `EDA.Integration`."
  @spec from_raw(map()) :: EDA.Integration.t()
  def from_raw(raw) when is_map(raw), do: EDA.Integration.from_raw(raw)
end
