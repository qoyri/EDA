defmodule EDA.Sticker do
  @moduledoc """
  Represents a Discord sticker.

  Types: `:standard` (Nitro stickers), `:guild` (guild-specific).
  Formats: `:png`, `:apng`, `:lottie`, `:gif`.
  """

  use EDA.Event.Access

  defstruct [
    :id,
    :pack_id,
    :name,
    :description,
    :tags,
    :type,
    :format_type,
    :available,
    :guild_id,
    :user,
    :sort_value
  ]

  @type t :: %__MODULE__{
          id: String.t() | nil,
          pack_id: String.t() | nil,
          name: String.t() | nil,
          description: String.t() | nil,
          tags: String.t() | nil,
          type: :standard | :guild | integer() | nil,
          format_type: :png | :apng | :lottie | :gif | integer() | nil,
          available: boolean() | nil,
          guild_id: String.t() | nil,
          user: EDA.User.t() | nil,
          sort_value: integer() | nil
        }

  @sticker_types %{1 => :standard, 2 => :guild}
  @format_types %{1 => :png, 2 => :apng, 3 => :lottie, 4 => :gif}

  @discord_cdn "https://cdn.discordapp.com"

  @doc """
  Converts a raw Discord sticker map into this struct.

  Resolves integer `type` and `format_type` to atoms where known.

  ## Examples

      iex> EDA.Sticker.from_raw(%{"id" => "1", "name" => "wave", "type" => 2, "format_type" => 1})
      %EDA.Sticker{id: "1", name: "wave", type: :guild, format_type: :png}
  """
  @spec from_raw(map()) :: t()
  def from_raw(raw) when is_map(raw) do
    %__MODULE__{
      id: raw["id"],
      pack_id: raw["pack_id"],
      name: raw["name"],
      description: raw["description"],
      tags: raw["tags"],
      type: resolve_type(raw["type"]),
      format_type: resolve_format(raw["format_type"]),
      available: raw["available"],
      guild_id: raw["guild_id"],
      user: parse_user(raw["user"]),
      sort_value: raw["sort_value"]
    }
  end

  @doc """
  Returns the CDN URL for a sticker.

  Lottie stickers return a `.json` URL, GIF stickers return `.gif`,
  and all others return `.png`. Returns `nil` if the sticker has no id.

  ## Examples

      iex> EDA.Sticker.cdn_url(%EDA.Sticker{id: "1", format_type: :lottie})
      "https://cdn.discordapp.com/stickers/1.json"

      iex> EDA.Sticker.cdn_url(%EDA.Sticker{id: "1", format_type: :gif})
      "https://cdn.discordapp.com/stickers/1.gif"

      iex> EDA.Sticker.cdn_url(%EDA.Sticker{id: "1", format_type: :png})
      "https://cdn.discordapp.com/stickers/1.png"

      iex> EDA.Sticker.cdn_url(%EDA.Sticker{id: nil})
      nil
  """
  @spec cdn_url(t()) :: String.t() | nil
  def cdn_url(%__MODULE__{id: nil}), do: nil

  def cdn_url(%__MODULE__{id: id, format_type: :lottie}),
    do: "#{@discord_cdn}/stickers/#{id}.json"

  def cdn_url(%__MODULE__{id: id, format_type: :gif}), do: "#{@discord_cdn}/stickers/#{id}.gif"
  def cdn_url(%__MODULE__{id: id}), do: "#{@discord_cdn}/stickers/#{id}.png"

  defp resolve_type(int) when is_integer(int), do: Map.get(@sticker_types, int, int)
  defp resolve_type(other), do: other

  @doc false
  # Shared with EDA.Sticker.Item.
  def resolve_format(int) when is_integer(int), do: Map.get(@format_types, int, int)
  def resolve_format(other), do: other

  defp parse_user(nil), do: nil
  defp parse_user(raw) when is_map(raw), do: EDA.User.from_raw(raw)
end
