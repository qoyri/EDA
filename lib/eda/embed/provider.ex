defmodule EDA.Embed.Provider do
  @moduledoc """
  The site a link embed comes from, such as YouTube. Discord sets it; a bot cannot send one.
  """

  use EDA.Event.Access

  defstruct [:name, :url]

  @type t :: %__MODULE__{name: String.t() | nil, url: String.t() | nil}

  @doc false
  @spec from_raw(map() | nil) :: t() | nil
  def from_raw(nil), do: nil
  def from_raw(raw) when is_map(raw), do: %__MODULE__{name: raw["name"], url: raw["url"]}
end
