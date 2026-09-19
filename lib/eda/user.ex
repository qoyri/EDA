defmodule EDA.User do
  @moduledoc "Represents a Discord user."
  use EDA.Event.Access

  @discord_cdn "https://cdn.discordapp.com"

  defstruct [
    :id,
    :username,
    :avatar,
    :discriminator,
    :public_flags,
    :flags,
    :accent_color,
    :bot,
    :system,
    :banner,
    :global_name,
    :primary_guild
  ]

  @type t :: %__MODULE__{
          id: String.t() | nil,
          username: String.t() | nil,
          avatar: String.t() | nil,
          discriminator: String.t() | nil,
          public_flags: integer() | nil,
          flags: integer() | nil,
          accent_color: integer() | nil,
          bot: boolean() | nil,
          system: boolean() | nil,
          banner: String.t() | nil,
          global_name: String.t() | nil,
          primary_guild: EDA.User.PrimaryGuild.t() | nil
        }

  @spec from_raw(map()) :: t()
  def from_raw(raw) when is_map(raw) do
    %__MODULE__{
      id: raw["id"],
      username: raw["username"],
      avatar: raw["avatar"],
      discriminator: raw["discriminator"],
      public_flags: raw["public_flags"],
      flags: raw["flags"],
      accent_color: raw["accent_color"],
      bot: raw["bot"],
      system: raw["system"],
      banner: raw["banner"],
      global_name: raw["global_name"],
      primary_guild: EDA.User.PrimaryGuild.from_raw(raw["primary_guild"])
    }
  end

  @doc "Returns a mention string like `<@id>`. Accepts structs and raw maps."
  @spec mention(t() | map()) :: String.t()
  def mention(%__MODULE__{id: id}), do: "<@#{id}>"
  def mention(%{"id" => id}), do: "<@#{id}>"

  @doc """
  Returns the CDN URL for the user's avatar, or `nil` if none set.

  Accepts both `%EDA.User{}` structs and raw maps (from cache).
  """
  @spec avatar_url(t() | map()) :: String.t() | nil
  def avatar_url(%__MODULE__{avatar: nil}), do: nil

  def avatar_url(%__MODULE__{id: id, avatar: avatar}),
    do: "#{@discord_cdn}/avatars/#{id}/#{avatar}.png"

  def avatar_url(%{"avatar" => nil}), do: nil

  def avatar_url(%{"avatar" => a, "id" => id}) when is_binary(a),
    do: "#{@discord_cdn}/avatars/#{id}/#{a}.png"

  @doc """
  URL of the user's server tag badge, or `nil`.

  discord.js exposes the same helper on the user (`guildTagBadgeURL()`) rather than
  only on the nested object, because that is where callers have it to hand. Accepts a
  struct or a raw user map, like `avatar_url/1`.

  ## Options

  - `:size` — power of two between 16 and 4096

  ## Examples

      iex> EDA.User.guild_tag_badge_url(%EDA.User{primary_guild: %EDA.User.PrimaryGuild{identity_guild_id: "1", badge: "abc"}})
      "https://cdn.discordapp.com/guild-tag-badges/1/abc.png"

      iex> EDA.User.guild_tag_badge_url(%EDA.User{})
      nil
  """
  @spec guild_tag_badge_url(t() | map(), keyword()) :: String.t() | nil
  def guild_tag_badge_url(user, opts \\ [])

  def guild_tag_badge_url(%__MODULE__{primary_guild: pg}, opts),
    do: EDA.User.PrimaryGuild.badge_url(pg, opts)

  def guild_tag_badge_url(%{"primary_guild" => raw}, opts),
    do: raw |> EDA.User.PrimaryGuild.from_raw() |> EDA.User.PrimaryGuild.badge_url(opts)

  def guild_tag_badge_url(_user, _opts), do: nil

  @doc """
  The server tag the user is currently displaying, or `nil`.

  Returns `nil` when there is no primary guild, or when the tag exists but is not
  being shown — `identity_enabled` is tri-state, see `EDA.User.PrimaryGuild`.

  ## Examples

      iex> EDA.User.server_tag(%EDA.User{primary_guild: %EDA.User.PrimaryGuild{identity_enabled: true, tag: "DISC"}})
      "DISC"

      iex> EDA.User.server_tag(%EDA.User{primary_guild: %EDA.User.PrimaryGuild{identity_enabled: false, tag: "DISC"}})
      nil

      iex> EDA.User.server_tag(%EDA.User{})
      nil
  """
  @spec server_tag(t() | map()) :: String.t() | nil
  def server_tag(user)

  def server_tag(%__MODULE__{primary_guild: pg}), do: tag_if_displayed(pg)

  def server_tag(%{"primary_guild" => raw}),
    do: raw |> EDA.User.PrimaryGuild.from_raw() |> tag_if_displayed()

  def server_tag(_user), do: nil

  defp tag_if_displayed(pg) do
    if EDA.User.PrimaryGuild.displayed?(pg), do: pg.tag
  end

  @doc """
  Returns the display name (global_name if set, otherwise username).

  Accepts both `%EDA.User{}` structs and raw maps (from cache).
  """
  @spec display_name(t() | map()) :: String.t() | nil
  def display_name(%__MODULE__{global_name: name}) when is_binary(name), do: name
  def display_name(%__MODULE__{username: name}), do: name
  def display_name(%{"global_name" => name}) when is_binary(name), do: name
  def display_name(%{"username" => name}), do: name

  @doc "Returns `true` if the user is a bot. Accepts structs and raw maps."
  @spec bot?(t() | map()) :: boolean()
  def bot?(%__MODULE__{bot: true}), do: true
  def bot?(%{"bot" => true}), do: true
  def bot?(_), do: false

  # ── Entity Manager ──

  use EDA.Entity

  @doc """
  Fetches a user by ID. Checks cache first, falls back to REST.
  """
  @spec fetch(t() | String.t() | integer()) :: {:ok, t()} | {:error, term()}
  def fetch(%__MODULE__{id: id}), do: fetch(id)

  def fetch(user_id) do
    case EDA.Cache.get_user(user_id) do
      nil -> EDA.API.User.get(user_id) |> parse_response()
      raw -> {:ok, from_raw(raw)}
    end
  end

  @doc """
  Fetches a user by ID. Raises on error.
  """
  @spec fetch!(t() | String.t() | integer()) :: t()
  def fetch!(user_id) do
    case fetch(user_id) do
      {:ok, user} -> user
      {:error, reason} -> raise "Failed to fetch user: #{inspect(reason)}"
    end
  end

  @doc """
  Creates a DM channel with a user. Returns a `%EDA.Channel{}` struct.
  """
  @spec create_dm(t() | String.t() | integer()) :: {:ok, EDA.Channel.t()} | {:error, term()}
  def create_dm(%__MODULE__{id: id}), do: create_dm(id)

  def create_dm(user_id) do
    case EDA.API.User.create_dm(user_id) do
      {:ok, raw} when is_map(raw) -> {:ok, EDA.Channel.from_raw(raw)}
      {:error, _} = err -> err
    end
  end
end
