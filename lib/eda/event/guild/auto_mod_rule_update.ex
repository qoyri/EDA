defmodule EDA.Event.AutoModRuleUpdate do
  @moduledoc """
  Sent when an Auto Moderation rule is updated. Delivers an `EDA.AutoMod`, not a struct of its
  own.

  The consumer receives `{:AUTO_MODERATION_RULE_UPDATE, %EDA.AutoMod{}}`. This module only parses
  the payload.
  """

  @doc "Parses the `AUTO_MODERATION_RULE_UPDATE` payload into an `EDA.AutoMod`."
  @spec from_raw(map()) :: EDA.AutoMod.t()
  def from_raw(raw) when is_map(raw), do: EDA.AutoMod.from_raw(raw)
end
