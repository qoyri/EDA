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
    :primary_guild,
    :premium_type,
    :mfa_enabled,
    :locale,
    :verified,
    :email,
    :avatar_decoration_data,
    :collectibles
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
          primary_guild: EDA.User.PrimaryGuild.t() | nil,
          premium_type: integer() | nil,
          mfa_enabled: boolean() | nil,
          locale: String.t() | nil,
          verified: boolean() | nil,
          email: String.t() | nil,
          avatar_decoration_data: map() | nil,
          collectibles: map() | nil
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
      primary_guild: EDA.User.PrimaryGuild.from_raw(raw["primary_guild"]),
      premium_type: raw["premium_type"],
      mfa_enabled: raw["mfa_enabled"],
      locale: raw["locale"],
      verified: raw["verified"],
      email: raw["email"],
      avatar_decoration_data: raw["avatar_decoration_data"],
      collectibles: raw["collectibles"]
    }
  end

  @premium_types %{0 => :none, 1 => :nitro_classic, 2 => :nitro, 3 => :nitro_basic}

  @typedoc "A Nitro tier name."
  @type premium_type :: :none | :nitro_classic | :nitro | :nitro_basic | :unknown | nil

  @doc """
  Names the user's Nitro tier.

  Returns `nil` when Discord did not send the field, which is the usual case: `premium_type`
  needs the `identify.premium` OAuth2 scope and never appears on a user seen through the
  gateway or the REST API. `nil` therefore means *not known*.

  `:none` is only meaningful for an app **approved** for `identify.premium`, a scope Discord
  grants to partners only. For every other app Discord answers `0` whatever the user's
  subscription, so `:none` there says nothing about their Nitro either.

  ## Examples

      iex> EDA.User.premium_type(%EDA.User{premium_type: 2})
      :nitro

      iex> EDA.User.premium_type(%EDA.User{premium_type: 0})
      :none

      iex> EDA.User.premium_type(%EDA.User{})
      nil

      iex> EDA.User.premium_type(%EDA.User{premium_type: 99})
      :unknown
  """
  @spec premium_type(t() | map() | integer() | nil) :: premium_type()
  def premium_type(%__MODULE__{premium_type: value}), do: premium_type(value)
  def premium_type(%{"premium_type" => value}), do: premium_type(value)
  def premium_type(nil), do: nil
  def premium_type(value) when is_integer(value), do: Map.get(@premium_types, value, :unknown)
  def premium_type(_other), do: nil

  @doc """
  Returns `true` if the user is known to have some form of Nitro.

  `false` covers both "no Nitro" and "not told", since neither entitles the user to
  anything — see `premium_type/1` if you need to tell those apart.

  ## Examples

      iex> EDA.User.nitro?(%EDA.User{premium_type: 3})
      true

      iex> EDA.User.nitro?(%EDA.User{premium_type: 0})
      false

      iex> EDA.User.nitro?(%EDA.User{})
      false
  """
  @spec nitro?(t() | map() | integer() | nil) :: boolean()
  def nitro?(user), do: premium_type(user) in [:nitro_classic, :nitro, :nitro_basic]

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

  > #### Not the raw `display_name` field {: .info}
  >
  > Discord also sends an undocumented `display_name` on the user object, and it is **not**
  > the same answer: it is null whenever the user has no global name. Measured on a real
  > guild on 2026-09-19, 46 of 573 cached users had `display_name: null` — every bot among
  > them. This function falls back to the username instead, so it always names somebody.
  > Do not "fix" it by reading the raw field.
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
