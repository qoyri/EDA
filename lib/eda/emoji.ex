defmodule EDA.Emoji do
  @moduledoc """
  Represents a Discord emoji (unicode or custom guild emoji).

  Unicode emojis have only a `name` (the unicode character).
  Custom emojis have an `id`, `name`, and optional metadata.

  Implements `String.Chars` so you can interpolate an emoji directly
  into a message string and get the correct mention format.
  """

  use EDA.Event.Access

  defstruct [:id, :name, :animated, :roles, :user, :require_colons, :managed, :available]

  @type t :: %__MODULE__{
          id: String.t() | nil,
          name: String.t() | nil,
          animated: boolean() | nil,
          roles: [String.t()] | nil,
          user: EDA.User.t() | nil,
          require_colons: boolean() | nil,
          managed: boolean() | nil,
          available: boolean() | nil
        }

  @discord_cdn "https://cdn.discordapp.com"

  @doc """
  Converts a raw Discord emoji map into this struct.

  ## Examples

      iex> EDA.Emoji.from_raw(%{"id" => "123", "name" => "cool", "animated" => true})
      %EDA.Emoji{id: "123", name: "cool", animated: true}

      iex> EDA.Emoji.from_raw(%{"id" => nil, "name" => "👍"})
      %EDA.Emoji{id: nil, name: "👍"}
  """
  @spec from_raw(map()) :: t()
  def from_raw(raw) when is_map(raw) do
    %__MODULE__{
      id: raw["id"],
      name: raw["name"],
      animated: raw["animated"],
      roles: raw["roles"],
      user: parse_user(raw["user"]),
      require_colons: raw["require_colons"],
      managed: raw["managed"],
      available: raw["available"]
    }
  end

  @doc """
  Returns `true` if this is a custom emoji (has an id).

  ## Examples

      iex> EDA.Emoji.custom?(%EDA.Emoji{id: "123", name: "cool"})
      true

      iex> EDA.Emoji.custom?(%EDA.Emoji{id: nil, name: "👍"})
      false
  """
  @spec custom?(t()) :: boolean()
  def custom?(%__MODULE__{id: id}), do: id != nil

  @doc """
  Returns `true` if this is a unicode emoji (no id).

  ## Examples

      iex> EDA.Emoji.unicode?(%EDA.Emoji{id: nil, name: "👍"})
      true

      iex> EDA.Emoji.unicode?(%EDA.Emoji{id: "123", name: "cool"})
      false
  """
  @spec unicode?(t()) :: boolean()
  def unicode?(%__MODULE__{id: id}), do: id == nil

  @doc """
  Returns the API-formatted string for use in REST endpoints.

  Unicode emojis return just the name. Custom emojis return `name:id`.

  ## Examples

      iex> EDA.Emoji.api_name(%EDA.Emoji{id: nil, name: "👍"})
      "👍"

      iex> EDA.Emoji.api_name(%EDA.Emoji{id: "123", name: "cool"})
      "cool:123"
  """
  @spec api_name(t()) :: String.t()
  def api_name(%__MODULE__{id: nil, name: name}), do: name
  def api_name(%__MODULE__{id: id, name: name}), do: "#{name}:#{id}"

  @doc """
  Returns the mention string for embedding in messages.

  Unicode emojis return just the name. Custom emojis return `<:name:id>`
  or `<a:name:id>` for animated emojis.

  ## Examples

      iex> EDA.Emoji.mention(%EDA.Emoji{id: nil, name: "👍"})
      "👍"

      iex> EDA.Emoji.mention(%EDA.Emoji{id: "123", name: "cool", animated: false})
      "<:cool:123>"

      iex> EDA.Emoji.mention(%EDA.Emoji{id: "123", name: "cool", animated: true})
      "<a:cool:123>"
  """
  @spec mention(t()) :: String.t()
  def mention(%__MODULE__{id: nil, name: name}), do: name
  def mention(%__MODULE__{id: id, name: name, animated: true}), do: "<a:#{name}:#{id}>"
  def mention(%__MODULE__{id: id, name: name}), do: "<:#{name}:#{id}>"

  @doc """
  Returns the CDN URL for a custom emoji image.

  Returns `nil` for unicode emojis.
  Animated emojis get a `.gif` extension, others get `.png`.

  ## Examples

      iex> EDA.Emoji.image_url(%EDA.Emoji{id: "123", name: "cool", animated: true})
      "https://cdn.discordapp.com/emojis/123.gif"

      iex> EDA.Emoji.image_url(%EDA.Emoji{id: "123", name: "cool"})
      "https://cdn.discordapp.com/emojis/123.png"

      iex> EDA.Emoji.image_url(%EDA.Emoji{id: nil, name: "👍"})
      nil
  """
  @spec image_url(t()) :: String.t() | nil
  def image_url(%__MODULE__{id: nil}), do: nil
  def image_url(%__MODULE__{id: id, animated: true}), do: "#{@discord_cdn}/emojis/#{id}.gif"
  def image_url(%__MODULE__{id: id}), do: "#{@discord_cdn}/emojis/#{id}.png"

  defp parse_user(nil), do: nil
  defp parse_user(raw) when is_map(raw), do: EDA.User.from_raw(raw)

  defimpl String.Chars do
    def to_string(emoji), do: EDA.Emoji.mention(emoji)
  end
end
