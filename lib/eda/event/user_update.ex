defmodule EDA.Event.UserUpdate do
  @moduledoc """
  Sent when the bot's own user changes — its name or avatar. `EDA.Cache.me/0` is updated before
  the consumer sees it. Delivers an `EDA.User`, not a struct of its own.

  The consumer receives `{:USER_UPDATE, %EDA.User{}}`. This module only parses the payload.
  """

  @doc "Parses the `USER_UPDATE` payload into an `EDA.User`."
  @spec from_raw(map()) :: EDA.User.t()
  def from_raw(raw) when is_map(raw), do: EDA.User.from_raw(raw)
end
