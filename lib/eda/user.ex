defmodule EDA.User do
  @moduledoc """
  Represents a Discord user.

  `member` is set only on the users a guild message mentions, where Discord attaches their
  partial member (nickname, roles, join date…) as an `EDA.Member` with the message's
  `guild_id`; it is `nil` anywhere else.

  ## Fields only REST returns

  The gateway never sends `banner` or `accent_color`: not on a message's author, a member, a
  presence, nor the bot's own user in `READY`. On a user from an event they are `nil` whatever
  the profile holds; `EDA.User.fetch/1` returns them. `rest_only_fields/0` lists them.

  The user cache keeps them: a user seen on the gateway updates the cached entry without
  clearing the banner and accent colour a REST fetch put there.
  """
  use EDA.Event.Access
  @premium_types %{0 => :none, 1 => :nitro_classic, 2 => :nitro, 3 => :nitro_basic}

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
    :collectibles,
    :display_name_styles,
    :member
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
          premium_type: :none | :nitro_classic | :nitro | :nitro_basic | integer() | nil,
          mfa_enabled: boolean() | nil,
          locale: String.t() | nil,
          verified: boolean() | nil,
          email: String.t() | nil,
          avatar_decoration_data: EDA.User.AvatarDecoration.t() | nil,
          collectibles: EDA.User.Collectibles.t() | nil,
          display_name_styles: EDA.User.DisplayNameStyles.t() | nil,
          member: EDA.Member.t() | nil
        }

  @spec from_raw(map()) :: t()
  def from_raw(%__MODULE__{} = parsed), do: parsed

  def from_raw(raw) when is_map(raw) do
    %__MODULE__{
      id: :maps.get("id", raw, nil),
      username: :maps.get("username", raw, nil),
      avatar: :maps.get("avatar", raw, nil),
      discriminator: :maps.get("discriminator", raw, nil),
      public_flags: :maps.get("public_flags", raw, nil),
      flags: :maps.get("flags", raw, nil),
      accent_color: :maps.get("accent_color", raw, nil),
      bot: :maps.get("bot", raw, nil),
      system: :maps.get("system", raw, nil),
      banner: :maps.get("banner", raw, nil),
      global_name: :maps.get("global_name", raw, nil),
      primary_guild: EDA.User.PrimaryGuild.from_raw(:maps.get("primary_guild", raw, nil)),
      premium_type: EDA.Enum.name(@premium_types, :maps.get("premium_type", raw, nil)),
      mfa_enabled: :maps.get("mfa_enabled", raw, nil),
      locale: :maps.get("locale", raw, nil),
      verified: :maps.get("verified", raw, nil),
      email: :maps.get("email", raw, nil),
      avatar_decoration_data:
        EDA.User.AvatarDecoration.from_raw(:maps.get("avatar_decoration_data", raw, nil)),
      collectibles: EDA.User.Collectibles.from_raw(:maps.get("collectibles", raw, nil)),
      display_name_styles:
        EDA.User.DisplayNameStyles.from_raw(:maps.get("display_name_styles", raw, nil)),
      member: :maps.get("member", raw, nil) && EDA.Member.from_raw(:maps.get("member", raw, nil))
    }
  end

  @rest_only_fields [:banner, :accent_color]

  @doc """
  The fields Discord only returns over REST, never on the gateway: on a user from an event they
  are `nil`, which says nothing about the profile.

      iex> EDA.User.rest_only_fields()
      [:banner, :accent_color]
  """
  @spec rest_only_fields() :: [atom()]
  def rest_only_fields, do: @rest_only_fields

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

      iex> EDA.User.premium_type(%EDA.User{premium_type: :nitro})
      :nitro

      iex> EDA.User.premium_type(%EDA.User{premium_type: :none})
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

  def premium_type(value) when value in [:none, :nitro_classic, :nitro, :nitro_basic],
    do: value

  def premium_type(_other), do: nil

  @doc """
  Returns `true` if the user is known to have some form of Nitro.

  `false` covers both "no Nitro" and "not told", since neither entitles the user to
  anything — see `premium_type/1` if you need to tell those apart.

  ## Examples

      iex> EDA.User.nitro?(%EDA.User{premium_type: :nitro_basic})
      true

      iex> EDA.User.nitro?(%EDA.User{premium_type: :none})
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

  An animated avatar (its hash starts with `a_`) comes as a GIF unless another format is asked
  for. Accepts both `%EDA.User{}` structs and raw maps.

  ## Options

  - `:format` — `:png`, `:jpg`, `:webp` or `:gif`. Defaults to `:gif` when the image is animated
    and `:png` otherwise; `:webp` of an animated image stays animated (Discord recommends it for
    animated images). `:gif` of a still image raises, since Discord answers 415
  - `:size` — a power of two from 16 to 4096
  - `:animated` — `false` for the still of an animated image

  ## Examples

      iex> EDA.User.avatar_url(%EDA.User{id: "1", avatar: "abc"})
      "https://cdn.discordapp.com/avatars/1/abc.png"

      iex> EDA.User.avatar_url(%EDA.User{id: "1", avatar: "a_abc"}, size: 256)
      "https://cdn.discordapp.com/avatars/1/a_abc.gif?size=256"

      iex> EDA.User.avatar_url(%EDA.User{id: "1", avatar: "a_abc"}, format: :webp)
      "https://cdn.discordapp.com/avatars/1/a_abc.webp?animated=true"
  """
  @spec avatar_url(t() | map(), keyword()) :: String.t() | nil
  def avatar_url(user, opts \\ [])

  def avatar_url(%__MODULE__{avatar: nil}, _opts), do: nil

  def avatar_url(%__MODULE__{id: id, avatar: avatar}, opts),
    do: EDA.CDN.url("avatars/#{id}/#{avatar}", EDA.CDN.animated_hash?(avatar), opts)

  def avatar_url(%{"avatar" => nil}, _opts), do: nil

  def avatar_url(%{"avatar" => a, "id" => id}, opts) when is_binary(a),
    do: EDA.CDN.url("avatars/#{id}/#{a}", EDA.CDN.animated_hash?(a), opts)

  @doc """
  The URL of the avatar Discord shows a user who has not set one: one of six images, picked
  from the id (or, for an account that still has a discriminator, from it). Always a PNG.

      iex> EDA.User.default_avatar_url(%EDA.User{id: "80351110224678912", discriminator: "0"})
      "https://cdn.discordapp.com/embed/avatars/5.png"
  """
  @spec default_avatar_url(t() | map()) :: String.t()
  def default_avatar_url(%__MODULE__{id: id, discriminator: discriminator}),
    do: default_avatar(id, discriminator)

  def default_avatar_url(%{"id" => id} = raw), do: default_avatar(id, raw["discriminator"])

  defp default_avatar(id, discriminator) do
    index =
      case discriminator do
        d when d in [nil, "0", "0000"] -> Bitwise.bsr(String.to_integer(id), 22) |> rem(6)
        d -> d |> String.to_integer() |> rem(5)
      end

    "#{EDA.CDN.base()}/embed/avatars/#{index}.png"
  end

  @doc """
  The avatar Discord shows: the user's own, or the default one. Takes the options of
  `avatar_url/2`, which apply only to the user's own avatar.

      iex> EDA.User.display_avatar_url(%EDA.User{id: "1", avatar: nil, discriminator: "0"})
      "https://cdn.discordapp.com/embed/avatars/0.png"
  """
  @spec display_avatar_url(t() | map(), keyword()) :: String.t()
  def display_avatar_url(user, opts \\ []), do: avatar_url(user, opts) || default_avatar_url(user)

  @doc """
  The URL of the user's profile banner, or `nil`. Discord sends `banner` only on a user fetched
  over REST. Takes the options of `avatar_url/2`.

      iex> EDA.User.banner_url(%EDA.User{id: "1", banner: "a_b"}, format: :webp)
      "https://cdn.discordapp.com/banners/1/a_b.webp?animated=true"
  """
  @spec banner_url(t() | map(), keyword()) :: String.t() | nil
  def banner_url(user, opts \\ [])
  def banner_url(%__MODULE__{banner: nil}, _opts), do: nil

  def banner_url(%__MODULE__{id: id, banner: banner}, opts),
    do: EDA.CDN.url("banners/#{id}/#{banner}", EDA.CDN.animated_hash?(banner), opts)

  def banner_url(%{"banner" => b, "id" => id}, opts) when is_binary(b),
    do: EDA.CDN.url("banners/#{id}/#{b}", EDA.CDN.animated_hash?(b), opts)

  def banner_url(_user, _opts), do: nil

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
  The badges on the user's profile, from `public_flags`.

  `EDA.User.Flags` has the whole table, and `badge?/2` asks about one badge. Accepts a struct or
  a raw user map, and gives `[]` for a user Discord sent without flags.

  ## Examples

      iex> EDA.User.badges(%EDA.User{public_flags: 64})
      [:hypesquad_online_house_1]

      iex> EDA.User.badges(%EDA.User{})
      []
  """
  @spec badges(t() | map()) :: [EDA.User.Flags.flag()]
  def badges(%__MODULE__{public_flags: flags}), do: EDA.User.Flags.to_list(flags)
  def badges(%{"public_flags" => flags}), do: EDA.User.Flags.to_list(flags)
  def badges(_user), do: []

  @doc """
  Whether the user has a badge.

      iex> EDA.User.badge?(%EDA.User{public_flags: 64}, :hypesquad_online_house_1)
      true

      iex> EDA.User.badge?(%EDA.User{public_flags: 64}, :staff)
      false
  """
  @spec badge?(t() | map(), EDA.User.Flags.flag()) :: boolean()
  def badge?(%__MODULE__{public_flags: flags}, badge), do: EDA.User.Flags.has?(flags, badge)
  def badge?(%{"public_flags" => flags}, badge), do: EDA.User.Flags.has?(flags, badge)
  def badge?(_user, _badge), do: false

  @doc """
  URL of the frame around the user's avatar, or `nil`.

  PNG only, animated ones included — see `EDA.User.AvatarDecoration`. Accepts a struct or a raw
  user map, like `avatar_url/1`.

  ## Options

  - `:size` — power of two between 16 and 4096

  ## Examples

      iex> EDA.User.avatar_decoration_url(%EDA.User{avatar_decoration_data: %EDA.User.AvatarDecoration{asset: "a_abc"}})
      "https://cdn.discordapp.com/avatar-decoration-presets/a_abc.png"

      iex> EDA.User.avatar_decoration_url(%EDA.User{})
      nil
  """
  @spec avatar_decoration_url(t() | map(), keyword()) :: String.t() | nil
  def avatar_decoration_url(user, opts \\ [])

  def avatar_decoration_url(%__MODULE__{avatar_decoration_data: decoration}, opts),
    do: EDA.User.AvatarDecoration.url(decoration, opts)

  def avatar_decoration_url(%{"avatar_decoration_data" => raw}, opts),
    do: raw |> EDA.User.AvatarDecoration.from_raw() |> EDA.User.AvatarDecoration.url(opts)

  def avatar_decoration_url(_user, _opts), do: nil

  @doc """
  URL of the plate behind the user's name, or `nil`.

  ## Options

  - `:format` — `:animated` (default, `.webm`) or `:static` (`.png`), see `EDA.User.Nameplate`

  ## Examples

      iex> EDA.User.nameplate_url(%EDA.User{collectibles: %EDA.User.Collectibles{nameplate: %EDA.User.Nameplate{asset: "nameplates/zodiac/virgo/"}}}, format: :static)
      "https://cdn.discordapp.com/assets/collectibles/nameplates/zodiac/virgo/static.png"

      iex> EDA.User.nameplate_url(%EDA.User{})
      nil
  """
  @spec nameplate_url(t() | map(), keyword()) :: String.t() | nil
  def nameplate_url(user, opts \\ [])

  def nameplate_url(%__MODULE__{collectibles: %EDA.User.Collectibles{nameplate: plate}}, opts),
    do: EDA.User.Nameplate.url(plate, opts)

  def nameplate_url(%{"collectibles" => raw}, opts) when is_map(raw),
    do: raw["nameplate"] |> EDA.User.Nameplate.from_raw() |> EDA.User.Nameplate.url(opts)

  def nameplate_url(_user, _opts), do: nil

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

  Accepts both `%EDA.User{}` structs and raw maps.

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
      user -> {:ok, user}
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

  @doc "Fetches the bot's own user from Discord. `EDA.Cache.me/0` holds it without a request."
  @spec me() :: {:ok, t()} | {:error, term()}
  def me, do: EDA.API.User.me() |> parse_user()

  @doc "Changes the bot's `:username`, `:avatar` or `:banner`."
  @spec modify_me(map() | keyword()) :: {:ok, t()} | {:error, term()}
  def modify_me(opts), do: EDA.API.User.modify_me(opts) |> parse_user()

  @doc """
  One page of the guilds the bot is in, as partial `EDA.Guild` structs. Takes `:before`,
  `:after`, `:limit` and `with_counts: true`.
  """
  @spec guilds(keyword()) :: {:ok, [EDA.Guild.t()]} | {:error, term()}
  def guilds(opts \\ []) do
    case EDA.API.User.guilds(opts) do
      {:ok, list} when is_list(list) -> {:ok, Enum.map(list, &EDA.Guild.from_raw/1)}
      {:error, _} = err -> err
    end
  end

  @doc "A lazy stream of every guild the bot is in, as partial `EDA.Guild` structs."
  @spec stream_guilds(keyword()) :: Enumerable.t()
  def stream_guilds(opts \\ []),
    do: opts |> EDA.API.User.stream_guilds() |> Stream.map(&EDA.Guild.from_raw/1)

  defp parse_user({:ok, raw}) when is_map(raw), do: {:ok, from_raw(raw)}
  defp parse_user({:error, _} = err), do: err
end
