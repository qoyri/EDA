defmodule EDA.Event.StageInstanceDelete do
  @moduledoc """
  Sent when a stage ends. Delivers an `EDA.StageInstance`, not a struct of its own.

  The consumer receives `{:STAGE_INSTANCE_DELETE, %EDA.StageInstance{}}`. This module only parses the
  payload.
  """

  @doc "Parses the `STAGE_INSTANCE_DELETE` payload into an `EDA.StageInstance`."
  @spec from_raw(map()) :: EDA.StageInstance.t()
  def from_raw(raw) when is_map(raw), do: EDA.StageInstance.from_raw(raw)
end
