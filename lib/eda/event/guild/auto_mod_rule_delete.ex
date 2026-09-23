defmodule EDA.Event.AutoModRuleDelete do
  @moduledoc """
  Sent when an Auto Moderation rule is deleted. Delivers an `EDA.AutoMod`, not a struct of its
  own.

  The consumer receives `{:AUTO_MODERATION_RULE_DELETE, %EDA.AutoMod{}}`. This module only parses
  the payload.
  """

  @doc "Parses the `AUTO_MODERATION_RULE_DELETE` payload into an `EDA.AutoMod`."
  @spec from_raw(map()) :: EDA.AutoMod.t()
  def from_raw(raw) when is_map(raw), do: EDA.AutoMod.from_raw(raw)
end
