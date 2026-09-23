defmodule EDA.Integration.Account do
  @moduledoc """
  The account behind an integration: the Twitch or YouTube channel, or the application.
  """

  use EDA.Event.Access

  defstruct [:id, :name]

  @type t :: %__MODULE__{id: String.t() | nil, name: String.t() | nil}

  @doc false
  @spec from_raw(map() | nil) :: t() | nil
  def from_raw(nil), do: nil
  def from_raw(raw) when is_map(raw), do: %__MODULE__{id: raw["id"], name: raw["name"]}
end
