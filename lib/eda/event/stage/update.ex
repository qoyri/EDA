defmodule EDA.Event.StageInstanceUpdate do
  @moduledoc """
  Sent when a live stage is updated. Delivers an `EDA.StageInstance`, not a struct of its own.

  The consumer receives `{:STAGE_INSTANCE_UPDATE, %EDA.StageInstance{}}`. This module only parses the
  payload.
  """

  @doc "Parses the `STAGE_INSTANCE_UPDATE` payload into an `EDA.StageInstance`."
  @spec from_raw(map()) :: EDA.StageInstance.t()
  def from_raw(raw) when is_map(raw), do: EDA.StageInstance.from_raw(raw)
end
