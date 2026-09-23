defmodule EDA.Embed.Field do
  @moduledoc """
  A name and value pair in an embed; `inline` fields sit side by side, up to three on a row.
  """

  use EDA.Event.Access

  defstruct [:name, :value, inline: false]

  @type t :: %__MODULE__{
          name: String.t() | nil,
          value: String.t() | nil,
          inline: boolean()
        }

  @doc false
  @spec from_raw(map()) :: t()
  def from_raw(raw) when is_map(raw) do
    %__MODULE__{name: raw["name"], value: raw["value"], inline: raw["inline"] == true}
  end
end
