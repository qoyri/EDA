defmodule EDA.Sticker.Item do
  @moduledoc """
  A sticker as a message carries it: enough to show it, with `EDA.Sticker.cdn_url/1` on
  `to_sticker/1`, or to fetch it whole with `EDA.API.Sticker.get/1`.
  """

  use EDA.Event.Access

  defstruct [:id, :name, :format_type]

  @type t :: %__MODULE__{
          id: String.t() | nil,
          name: String.t() | nil,
          format_type: :png | :apng | :lottie | :gif | integer() | nil
        }

  @doc false
  @spec from_raw(map()) :: t()
  def from_raw(%__MODULE__{} = parsed), do: parsed

  def from_raw(raw) when is_map(raw) do
    %__MODULE__{
      id: :maps.get("id", raw, nil),
      name: :maps.get("name", raw, nil),
      format_type: EDA.Sticker.resolve_format(:maps.get("format_type", raw, nil))
    }
  end

  @doc """
  The item as a partial `EDA.Sticker`, for the functions that take one.

      iex> %EDA.Sticker.Item{id: "1", name: "wave", format_type: :gif}
      ...> |> EDA.Sticker.Item.to_sticker()
      ...> |> EDA.Sticker.cdn_url()
      "https://cdn.discordapp.com/stickers/1.gif"
  """
  @spec to_sticker(t()) :: EDA.Sticker.t()
  def to_sticker(%__MODULE__{id: id, name: name, format_type: format}),
    do: %EDA.Sticker{id: id, name: name, format_type: format}
end
