defmodule EDA.Event.UserUpdate do
  @moduledoc "Dispatched when the bot's own user changes — its name or avatar. `EDA.Cache.me/0` is updated before the consumer sees it."
  use EDA.Event.Access

  defstruct [:user]

  @type t :: %__MODULE__{user: EDA.User.t()}

  @doc "Converts a raw Discord payload into this event struct."
  @spec from_raw(map()) :: t()
  def from_raw(raw) when is_map(raw), do: %__MODULE__{user: EDA.User.from_raw(raw)}
end
