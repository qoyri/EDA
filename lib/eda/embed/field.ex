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
  def from_raw(%__MODULE__{} = parsed), do: parsed

  def from_raw(raw) when is_map(raw) do
    %__MODULE__{
      name: :maps.get("name", raw, nil),
      value: :maps.get("value", raw, nil),
      inline: :maps.get("inline", raw, nil) == true
    }
  end
end
