defmodule EDA.Sticker.Pack do
  @moduledoc "Represents a Discord sticker pack (collection of standard Nitro stickers)."

  use EDA.Event.Access

  defstruct [:id, :stickers, :name, :sku_id, :cover_sticker_id, :description, :banner_asset_id]

  @type t :: %__MODULE__{
          id: String.t() | nil,
          stickers: [EDA.Sticker.t()] | nil,
          name: String.t() | nil,
          sku_id: String.t() | nil,
          cover_sticker_id: String.t() | nil,
          description: String.t() | nil,
          banner_asset_id: String.t() | nil
        }

  @discord_cdn "https://cdn.discordapp.com"

  @doc """
  Converts a raw sticker pack map. Parses stickers into `EDA.Sticker` structs.

  ## Examples

      iex> EDA.Sticker.Pack.from_raw(%{"id" => "1", "name" => "Wumpus", "stickers" => []})
      %EDA.Sticker.Pack{id: "1", name: "Wumpus", stickers: []}
  """
  @spec from_raw(map()) :: t()
  def from_raw(raw) when is_map(raw) do
    stickers =
      (raw["stickers"] || [])
      |> Enum.map(&EDA.Sticker.from_raw/1)

    %__MODULE__{
      id: raw["id"],
      stickers: stickers,
      name: raw["name"],
      sku_id: raw["sku_id"],
      cover_sticker_id: raw["cover_sticker_id"],
      description: raw["description"],
      banner_asset_id: raw["banner_asset_id"]
    }
  end

  @doc """
  Returns the CDN URL for the pack's banner image.

  Returns `nil` if the pack has no `banner_asset_id`.

  ## Examples

      iex> EDA.Sticker.Pack.banner_url(%EDA.Sticker.Pack{id: "1", banner_asset_id: "abc"})
      "https://cdn.discordapp.com/app-assets/710982414301790216/store/abc.png"

      iex> EDA.Sticker.Pack.banner_url(%EDA.Sticker.Pack{id: "1", banner_asset_id: nil})
      nil
  """
  @spec banner_url(t()) :: String.t() | nil
  def banner_url(%__MODULE__{banner_asset_id: nil}), do: nil

  def banner_url(%__MODULE__{banner_asset_id: asset_id}) do
    "#{@discord_cdn}/app-assets/710982414301790216/store/#{asset_id}.png"
  end
end
