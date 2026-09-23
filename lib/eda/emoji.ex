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
  Animated emojis get a `.gif` extension, others get `.png`, unless another format is asked for.
  Discord recommends `format: :webp` for emojis.

  ## Options

  - `:format` — `:png`, `:jpg`, `:webp` or `:gif`. Defaults to `:gif` when the image is animated
    and `:png` otherwise; `:webp` of an animated image stays animated (Discord recommends it for
    animated images). `:gif` of a still image raises, since Discord answers 415
  - `:size` — a power of two from 16 to 4096
  - `:animated` — `false` for the still of an animated image


  ## Examples

      iex> EDA.Emoji.image_url(%EDA.Emoji{id: "123", name: "cool", animated: true})
      "https://cdn.discordapp.com/emojis/123.gif"

      iex> EDA.Emoji.image_url(%EDA.Emoji{id: "123", name: "cool"})
      "https://cdn.discordapp.com/emojis/123.png"

      iex> EDA.Emoji.image_url(%EDA.Emoji{id: nil, name: "👍"})
      nil
  """
  @spec image_url(t(), keyword()) :: String.t() | nil
  def image_url(emoji, opts \\ [])
  def image_url(%__MODULE__{id: nil}, _opts), do: nil

  def image_url(%__MODULE__{id: id, animated: animated}, opts),
    do: EDA.CDN.url("emojis/#{id}", animated == true, opts)

  defp parse_user(nil), do: nil
  defp parse_user(raw) when is_map(raw), do: EDA.User.from_raw(raw)

  # ── Entity Manager ──

  use EDA.Entity

  @doc "Lists a guild's emojis. See `EDA.API.Emoji.list/1`."
  @spec list(String.t() | integer()) :: {:ok, [t()]} | {:error, term()}
  def list(guild_id), do: EDA.API.Emoji.list(guild_id) |> parse_list()

  @doc """
  Fetches one of a guild's emojis.

  Named `fetch_emoji/2` rather than `fetch/2` because `Access.fetch/2` owns that arity.
  """
  @spec fetch_emoji(String.t() | integer(), String.t() | integer()) ::
          {:ok, t()} | {:error, term()}
  def fetch_emoji(guild_id, emoji_id),
    do: EDA.API.Emoji.get(guild_id, emoji_id) |> parse_response()

  @doc "Creates a guild emoji. Takes the parameters of `EDA.API.Emoji.create/2`."
  @spec create(String.t() | integer(), map()) :: {:ok, t()} | {:error, term()}
  def create(guild_id, params), do: EDA.API.Emoji.create(guild_id, params) |> parse_response()

  @doc "Modifies a guild emoji: its `name` or the `roles` allowed to use it."
  @spec modify(String.t() | integer(), t() | String.t() | integer(), map()) ::
          {:ok, t()} | {:error, term()}
  def modify(guild_id, %__MODULE__{id: id}, params), do: modify(guild_id, id, params)

  def modify(guild_id, emoji_id, params),
    do: EDA.API.Emoji.modify(guild_id, emoji_id, params) |> parse_response()

  @doc "Deletes a guild emoji."
  @spec delete(String.t() | integer(), t() | String.t() | integer()) :: :ok | {:error, term()}
  def delete(guild_id, %__MODULE__{id: id}), do: delete(guild_id, id)
  def delete(guild_id, emoji_id), do: EDA.API.Emoji.delete(guild_id, emoji_id)

  @doc """
  Lists the application's own emojis: up to 2000, usable by the bot anywhere without being
  uploaded to a guild.
  """
  @spec list_application() :: {:ok, [t()]} | {:error, term()}
  def list_application, do: EDA.API.Emoji.list_application() |> parse_list()

  @doc "Fetches one of the application's emojis."
  @spec fetch_application(String.t() | integer()) :: {:ok, t()} | {:error, term()}
  def fetch_application(emoji_id),
    do: EDA.API.Emoji.get_application(emoji_id) |> parse_response()

  @doc "Creates an application emoji. See `EDA.API.Emoji.create_application/2` for `image`."
  @spec create_application(String.t(), String.t() | binary()) :: {:ok, t()} | {:error, term()}
  def create_application(name, image),
    do: EDA.API.Emoji.create_application(name, image) |> parse_response()

  @doc "Renames an application emoji."
  @spec rename_application(t() | String.t() | integer(), String.t()) ::
          {:ok, t()} | {:error, term()}
  def rename_application(%__MODULE__{id: id}, name), do: rename_application(id, name)

  def rename_application(emoji_id, name),
    do: EDA.API.Emoji.modify_application(emoji_id, name) |> parse_response()

  @doc "Deletes an application emoji."
  @spec delete_application(t() | String.t() | integer()) :: :ok | {:error, term()}
  def delete_application(%__MODULE__{id: id}), do: delete_application(id)
  def delete_application(emoji_id), do: EDA.API.Emoji.delete_application(emoji_id)

  defp parse_list({:ok, list}) when is_list(list), do: {:ok, Enum.map(list, &from_raw/1)}
  defp parse_list({:error, _} = err), do: err

  defimpl String.Chars do
    def to_string(emoji), do: EDA.Emoji.mention(emoji)
  end
end
