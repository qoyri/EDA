defmodule EDA.Member do
  @moduledoc "Represents a Discord guild member."
  use EDA.Event.Access

  defstruct [
    :user,
    :nick,
    :avatar,
    :banner,
    :bio,
    :roles,
    :joined_at,
    :premium_since,
    :deaf,
    :mute,
    :pending,
    :permissions,
    :communication_disabled_until,
    :flags,
    :avatar_decoration_data,
    :collectibles,
    :display_name_styles,
    :guild_id
  ]

  @type t :: %__MODULE__{
          user: EDA.User.t() | nil,
          nick: String.t() | nil,
          avatar: String.t() | nil,
          banner: String.t() | nil,
          bio: String.t() | nil,
          roles: [String.t()] | nil,
          joined_at: DateTime.t() | nil,
          premium_since: DateTime.t() | nil,
          deaf: boolean() | nil,
          mute: boolean() | nil,
          pending: boolean() | nil,
          permissions: String.t() | nil,
          communication_disabled_until: DateTime.t() | nil,
          flags: integer() | nil,
          avatar_decoration_data: EDA.User.AvatarDecoration.t() | nil,
          collectibles: EDA.User.Collectibles.t() | nil,
          display_name_styles: EDA.User.DisplayNameStyles.t() | nil,
          guild_id: String.t() | nil
        }

  @spec from_raw(map()) :: t()
  def from_raw(%__MODULE__{} = parsed), do: parsed

  def from_raw(raw) when is_map(raw) do
    %__MODULE__{
      user: parse_user(:maps.get("user", raw, nil)),
      nick: :maps.get("nick", raw, nil),
      avatar: :maps.get("avatar", raw, nil),
      banner: :maps.get("banner", raw, nil),
      bio: :maps.get("bio", raw, nil),
      roles: :maps.get("roles", raw, nil),
      joined_at: EDA.Timestamp.parse(:maps.get("joined_at", raw, nil)),
      premium_since: EDA.Timestamp.parse(:maps.get("premium_since", raw, nil)),
      deaf: :maps.get("deaf", raw, nil),
      mute: :maps.get("mute", raw, nil),
      pending: :maps.get("pending", raw, nil),
      permissions: :maps.get("permissions", raw, nil),
      communication_disabled_until:
        EDA.Timestamp.parse(:maps.get("communication_disabled_until", raw, nil)),
      flags: :maps.get("flags", raw, nil),
      avatar_decoration_data:
        EDA.User.AvatarDecoration.from_raw(:maps.get("avatar_decoration_data", raw, nil)),
      collectibles: EDA.User.Collectibles.from_raw(:maps.get("collectibles", raw, nil)),
      display_name_styles:
        EDA.User.DisplayNameStyles.from_raw(:maps.get("display_name_styles", raw, nil)),
      guild_id: :maps.get("guild_id", raw, nil)
    }
  end

  @doc """
  What the member has done in this guild, from `flags`.

  `EDA.Member.Flags` has the whole table, and `flag?/2` asks about one. Accepts a struct or a raw
  member map, and gives `[]` for a member Discord sent without flags.

  ## Examples

      iex> EDA.Member.flags(%EDA.Member{flags: 3})
      [:did_rejoin, :completed_onboarding]

      iex> EDA.Member.flags(%EDA.Member{})
      []
  """
  @spec flags(t() | map()) :: [EDA.Member.Flags.flag()]
  def flags(%__MODULE__{flags: flags}), do: EDA.Member.Flags.to_list(flags)
  def flags(%{"flags" => flags}), do: EDA.Member.Flags.to_list(flags)
  def flags(_member), do: []

  @doc """
  Whether the member carries a flag.

      iex> EDA.Member.flag?(%EDA.Member{flags: 4}, :bypasses_verification)
      true

      iex> EDA.Member.flag?(%EDA.Member{flags: 4}, :is_guest)
      false
  """
  @spec flag?(t() | map(), EDA.Member.Flags.flag()) :: boolean()
  def flag?(%__MODULE__{flags: flags}, flag), do: EDA.Member.Flags.has?(flags, flag)
  def flag?(%{"flags" => flags}, flag), do: EDA.Member.Flags.has?(flags, flag)
  def flag?(_member, _flag), do: false

  defp parse_user(nil), do: nil
  defp parse_user(raw) when is_map(raw), do: EDA.User.from_raw(raw)

  @doc """
  When the member's timeout ends, or `nil` if they have never been timed out.

  May return a date in the **past**, in which case the timeout has expired — Discord
  leaves the field populated. Use `timed_out?/1` to ask whether it is currently active.
  JDA draws the same distinction with `getTimeOutEnd()` / `isTimedOut()`.

  Accepts a struct or a raw member map.

  ## Examples

      iex> EDA.Member.time_out_end(%EDA.Member{communication_disabled_until: "2099-01-01T00:00:00Z"})
      ~U[2099-01-01 00:00:00Z]

      iex> EDA.Member.time_out_end(%EDA.Member{})
      nil
  """
  @spec time_out_end(t() | map()) :: DateTime.t() | nil
  def time_out_end(member)

  def time_out_end(%__MODULE__{communication_disabled_until: until}), do: parse_timestamp(until)
  def time_out_end(%{"communication_disabled_until" => until}), do: parse_timestamp(until)
  def time_out_end(_member), do: nil

  @doc """
  Returns `true` while the member is currently timed out.

  Accepts a struct or a raw member map.

  > #### Not reflected in permissions {: .warning}
  >
  > Discord removes every permission except `VIEW_CHANNEL` and `READ_MESSAGE_HISTORY`
  > from a timed-out member, but `EDA.Permission.in_channel/3` does **not** account for
  > it — neither does JDA's `hasPermission`. Check this yourself before gating an action
  > on a permission.

  ## Examples

      iex> EDA.Member.timed_out?(%EDA.Member{communication_disabled_until: ~U[2099-01-01 00:00:00Z]})
      true

      iex> EDA.Member.timed_out?(%EDA.Member{communication_disabled_until: ~U[2020-01-01 00:00:00Z]})
      false

      iex> EDA.Member.timed_out?(%EDA.Member{})
      false
  """
  @spec timed_out?(t() | map()) :: boolean()
  def timed_out?(member) do
    case time_out_end(member) do
      nil -> false
      until -> DateTime.compare(until, DateTime.utc_now()) == :gt
    end
  end

  # A struct holds a DateTime; a raw member map from the cache holds Discord's string.
  defp parse_timestamp(value), do: EDA.Timestamp.parse(value)

  @doc """
  The URL of the member's avatar in this guild, or `nil` when they use their account's. Needs
  `guild_id`, which members from EDA's calls and events carry. Takes the options of
  `EDA.User.avatar_url/2`.

      iex> EDA.Member.avatar_url(%EDA.Member{guild_id: "1", avatar: "g", user: %EDA.User{id: "2"}})
      "https://cdn.discordapp.com/guilds/1/users/2/avatars/g.png"
  """
  @spec avatar_url(t(), keyword()) :: String.t() | nil
  def avatar_url(member, opts \\ [])

  def avatar_url(%__MODULE__{avatar: hash, guild_id: guild_id, user: %{id: user_id}}, opts)
      when is_binary(hash) and is_binary(guild_id),
      do:
        EDA.CDN.url(
          "guilds/#{guild_id}/users/#{user_id}/avatars/#{hash}",
          EDA.CDN.animated_hash?(hash),
          opts
        )

  def avatar_url(%__MODULE__{}, _opts), do: nil

  @doc """
  The avatar Discord shows for the member here: their guild avatar, else their account's, else
  the default one.

      iex> EDA.Member.display_avatar_url(%EDA.Member{guild_id: "1", user: %EDA.User{id: "2", avatar: "u"}})
      "https://cdn.discordapp.com/avatars/2/u.png"
  """
  @spec display_avatar_url(t(), keyword()) :: String.t() | nil
  def display_avatar_url(member, opts \\ [])

  def display_avatar_url(%__MODULE__{user: %EDA.User{} = user} = member, opts),
    do: avatar_url(member, opts) || EDA.User.display_avatar_url(user, opts)

  def display_avatar_url(%__MODULE__{} = member, opts), do: avatar_url(member, opts)

  @doc """
  The URL of the member's banner in this guild, or `nil`. Takes the options of
  `EDA.User.avatar_url/2`.
  """
  @spec banner_url(t(), keyword()) :: String.t() | nil
  def banner_url(member, opts \\ [])

  def banner_url(%__MODULE__{banner: hash, guild_id: guild_id, user: %{id: user_id}}, opts)
      when is_binary(hash) and is_binary(guild_id),
      do:
        EDA.CDN.url(
          "guilds/#{guild_id}/users/#{user_id}/banners/#{hash}",
          EDA.CDN.animated_hash?(hash),
          opts
        )

  def banner_url(%__MODULE__{}, _opts), do: nil

  @doc """
  The member's highest role in a guild, as an `EDA.Role`, or `nil` when they have none
  beyond `@everyone` (or their roles are not cached).

  "Highest" is the role with the greatest `position`, ties broken by the lower id, which is how
  Discord orders roles in the member list and in permission hierarchy checks.
  """
  @spec top_role(t() | map(), String.t() | integer()) :: EDA.Role.t() | nil
  def top_role(member, guild_id) do
    case roles(member, guild_id) do
      [top | _] -> top
      [] -> nil
    end
  end

  @doc """
  The position of the member's highest role in a guild; `0`, the position of `@everyone`, when
  they have no other role. Compare two members, or a member and a role, to know which one ranks
  above the other — Discord refuses to let a member act on someone at or above them.
  """
  @spec top_role_position(t() | map(), String.t() | integer()) :: non_neg_integer()
  def top_role_position(member, guild_id) do
    case top_role(member, guild_id) do
      nil -> 0
      role -> role.position || 0
    end
  end

  # ── Display ──

  @doc """
  The name Discord shows for the member here: their nickname, else their display name, else
  their username.

      iex> EDA.Member.display_name(%EDA.Member{nick: "Annie", user: %EDA.User{username: "ann"}})
      "Annie"
      iex> EDA.Member.display_name(%EDA.Member{user: %EDA.User{username: "ann", global_name: "Ann"}})
      "Ann"
  """
  @spec display_name(t()) :: String.t() | nil
  def display_name(%__MODULE__{nick: nick}) when is_binary(nick), do: nick
  def display_name(%__MODULE__{user: %EDA.User{} = user}), do: EDA.User.display_name(user)
  def display_name(%__MODULE__{}), do: nil

  @doc "Whether the member boosts the guild."
  @spec boosting?(t()) :: boolean()
  def boosting?(%__MODULE__{premium_since: since}), do: since != nil

  @doc """
  The member's roles as `EDA.Role` structs, highest first, from the role cache. Roles not in
  the cache are left out; `@everyone` is not among them.
  """
  @spec roles(t() | map(), String.t() | integer()) :: [EDA.Role.t()]
  def roles(member, guild_id) do
    guild_id = to_string(guild_id)

    member
    |> role_ids()
    |> Enum.map(&EDA.Cache.Role.get(guild_id, &1))
    |> Enum.reject(&is_nil/1)
    |> Enum.sort_by(&EDA.Role.rank/1, :desc)
  end

  @doc """
  The colour of the member's name: that of their highest role with one, or `nil`.
  """
  @spec color(t() | map(), String.t() | integer()) :: non_neg_integer() | nil
  def color(member, guild_id) do
    member
    |> roles(guild_id)
    |> Enum.map(&EDA.Role.color_value/1)
    |> Enum.find(&(&1 != 0))
  end

  # ── Hierarchy and moderation ──

  @doc """
  Whether the member owns the guild. Takes the guild, or its id to read the owner from the
  cache.
  """
  @spec owner?(t() | map(), EDA.Guild.t() | String.t() | integer()) :: boolean()
  def owner?(member, %EDA.Guild{owner_id: owner_id}), do: user_id(member) == owner_id

  def owner?(member, guild_id) do
    case EDA.Cache.get_guild(guild_id) do
      %EDA.Guild{owner_id: owner_id} -> user_id(member) == owner_id
      nil -> false
    end
  end

  @doc """
  Whether `actor` can act on `target` — a member or a role — as Discord's hierarchy allows:
  the owner can act on anyone but can be acted on by no one; otherwise the actor's highest role
  must be above the target's (or above the role). Reads the roles from the cache.

  It says nothing of permissions; `kickable?/2` and the others add those.
  """
  @spec can_interact?(t(), t() | EDA.Role.t(), String.t() | integer()) :: boolean()
  def can_interact?(actor, %EDA.Role{} = role, guild_id) do
    owner?(actor, guild_id) or
      case roles(actor, guild_id) do
        [top | _] -> EDA.Role.above?(top, role)
        [] -> false
      end
  end

  def can_interact?(actor, %__MODULE__{} = target, guild_id) do
    cond do
      owner?(target, guild_id) -> false
      owner?(actor, guild_id) -> true
      true -> top_rank(actor, guild_id) > top_rank(target, guild_id)
    end
  end

  @doc """
  Whether the bot can manage the member: it is not the bot itself, and the bot is above them.
  Needs the bot's member and the roles in the cache; `false` when they are not.
  """
  @spec manageable?(t(), String.t() | integer()) :: boolean()
  def manageable?(%__MODULE__{} = member, guild_id) do
    case bot_member(guild_id) do
      %__MODULE__{} = bot ->
        user_id(bot) != user_id(member) and can_interact?(bot, member, guild_id)

      nil ->
        false
    end
  end

  @doc "Whether the bot can kick the member: `manageable?/2` and `KICK_MEMBERS`."
  @spec kickable?(t(), String.t() | integer()) :: boolean()
  def kickable?(member, guild_id), do: manageable_with?(member, guild_id, :kick_members)

  @doc "Whether the bot can ban the member: `manageable?/2` and `BAN_MEMBERS`."
  @spec bannable?(t(), String.t() | integer()) :: boolean()
  def bannable?(member, guild_id), do: manageable_with?(member, guild_id, :ban_members)

  @doc """
  Whether the bot can time the member out: `manageable?/2`, `MODERATE_MEMBERS`, and the member
  is not an administrator, whom Discord never times out.
  """
  @spec moderatable?(t(), String.t() | integer()) :: boolean()
  def moderatable?(member, guild_id) do
    manageable_with?(member, guild_id, :moderate_members) and
      not permission?(member, guild_id, :administrator)
  end

  defp manageable_with?(member, guild_id, flag) do
    manageable?(member, guild_id) and permission?(bot_member(guild_id), guild_id, flag)
  end

  @doc false
  # The bot's own member in a guild, from the cache.
  def bot_member(guild_id) do
    with %EDA.User{id: id} <- EDA.Cache.me(),
         %__MODULE__{} = member <- EDA.Cache.get_member(guild_id, id) do
      member
    else
      _ -> nil
    end
  end

  @doc false
  # Whether the member holds a permission in the guild, as computed from the cached roles.
  def permission?(nil, _guild_id, _flag), do: false

  def permission?(member, guild_id, flag) do
    case EDA.Permission.for_member(member, guild_id) do
      {:ok, bitset} -> EDA.Permission.has?(bitset, flag)
      {:error, _} -> false
    end
  end

  defp top_rank(member, guild_id) do
    case roles(member, guild_id) do
      [top | _] -> EDA.Role.rank(top)
      [] -> {-1, 0}
    end
  end

  defp user_id(%__MODULE__{user: %{id: id}}), do: id
  defp user_id(%{"user" => %{"id" => id}}), do: id
  defp user_id(_), do: nil

  defp role_ids(%__MODULE__{roles: roles}), do: roles || []
  defp role_ids(%{"roles" => roles}), do: roles || []
  defp role_ids(_member), do: []

  # ── Entity Manager ──

  use EDA.Entity

  @doc """
  Fetches a member by guild ID and user ID. Checks cache first, falls back to REST.
  """
  @spec fetch_member(String.t() | integer(), String.t() | integer()) ::
          {:ok, t()} | {:error, term()}
  def fetch_member(guild_id, user_id) do
    case EDA.Cache.get_member(guild_id, user_id) do
      nil -> EDA.API.Member.get(guild_id, user_id) |> parse_response() |> put_guild(guild_id)
      member -> {:ok, member}
    end
  end

  # Discord's member object does not say which guild it belongs to; the caller does.
  defp put_guild({:ok, %__MODULE__{} = member}, guild_id),
    do: {:ok, %{member | guild_id: to_string(guild_id)}}

  defp put_guild(other, _guild_id), do: other

  @doc """
  Modifies a guild member.

  ## Options

  - `:reason` - Audit log reason
  """
  @spec modify(String.t() | integer(), t() | String.t() | integer(), map(), keyword()) ::
          {:ok, t()} | {:error, term()}
  def modify(guild_id, member, payload, opts \\ [])

  def modify(guild_id, %__MODULE__{user: %{id: uid}}, payload, opts),
    do: modify(guild_id, uid, payload, opts)

  def modify(guild_id, user_id, payload, opts)
      when (is_binary(user_id) or is_integer(user_id)) and is_map(payload) do
    EDA.API.Member.modify(guild_id, user_id, payload, opts) |> parse_response()
  end

  @doc """
  Modifies the bot's own member in a guild — its per-guild profile.

  Returns a `t:t/0`. Takes the same options as `EDA.API.Member.modify_me/2`: `:nick`,
  `:avatar`, `:banner`, `:bio` and `:reason`. `:avatar` and `:banner` accept a path, raw
  image bytes or a data URI, and `nil` clears the field so the account-wide value shows
  again.

  Only `:nick` needs a permission (`CHANGE_NICKNAME`); the appearance fields need none.

      EDA.Member.modify_me(guild_id, nick: "EDA", avatar: "priv/avatar.png")

  Fields you leave out are untouched, so setting a bio alone keeps the avatar and banner.

  `:bio` comes back on **this** response but not on a later `fetch_member/2`: Discord omits
  it from the guild member object. Read it from the struct this returns, or keep your own
  copy — a round trip will not give it back.
  """
  @spec modify_me(String.t() | integer(), keyword() | map()) :: {:ok, t()} | {:error, term()}
  def modify_me(guild_id, opts \\ []) do
    EDA.API.Member.modify_me(guild_id, opts) |> parse_response()
  end

  @doc """
  Kicks a member from a guild.

  ## Options

  - `:reason` - Audit log reason
  """
  @spec kick(String.t() | integer(), t() | String.t() | integer(), keyword()) ::
          :ok | {:error, term()}
  def kick(guild_id, member, opts \\ [])

  def kick(guild_id, %__MODULE__{user: %{id: uid}}, opts), do: kick(guild_id, uid, opts)

  def kick(guild_id, user_id, opts) when is_binary(user_id) or is_integer(user_id) do
    EDA.API.Member.remove(guild_id, user_id, opts)
  end

  @doc """
  Adds a role to a guild member.

  ## Options

  - `:reason` - Audit log reason
  """
  @spec add_role(
          String.t() | integer(),
          t() | String.t() | integer(),
          String.t() | integer(),
          keyword()
        ) :: :ok | {:error, term()}
  def add_role(guild_id, member, role_id, opts \\ [])

  def add_role(guild_id, %__MODULE__{user: %{id: uid}}, role_id, opts),
    do: add_role(guild_id, uid, role_id, opts)

  def add_role(guild_id, user_id, role_id, opts)
      when is_binary(user_id) or is_integer(user_id) do
    EDA.API.Member.add_role(guild_id, user_id, role_id, opts)
  end

  @doc """
  Removes a role from a guild member.

  ## Options

  - `:reason` - Audit log reason
  """
  @spec remove_role(
          String.t() | integer(),
          t() | String.t() | integer(),
          String.t() | integer(),
          keyword()
        ) :: :ok | {:error, term()}
  def remove_role(guild_id, member, role_id, opts \\ [])

  def remove_role(guild_id, %__MODULE__{user: %{id: uid}}, role_id, opts),
    do: remove_role(guild_id, uid, role_id, opts)

  def remove_role(guild_id, user_id, role_id, opts)
      when is_binary(user_id) or is_integer(user_id) do
    EDA.API.Member.remove_role(guild_id, user_id, role_id, opts)
  end

  @doc """
  Applies a changeset to a member. No-op if the changeset has no changes.

  Requires `guild_id` since members are guild-scoped.

  ## Options

  - `:reason` - Audit log reason
  """
  @spec apply_changeset(String.t() | integer(), Changeset.t(), keyword()) ::
          {:ok, t()} | {:error, term()}
  def apply_changeset(guild_id, changeset, opts \\ [])

  def apply_changeset(guild_id, %Changeset{module: __MODULE__, entity: entity} = cs, opts) do
    if Changeset.changed?(cs) do
      modify(guild_id, entity, Changeset.changes(cs), opts)
    else
      {:ok, entity}
    end
  end

  @doc """
  Lists one page of a guild's members. Takes `:limit` (1–1000) and `:after`. Needs the
  `:guild_members` intent.
  """
  @spec list(String.t() | integer(), keyword()) :: {:ok, [t()]} | {:error, term()}
  def list(guild_id, opts \\ []),
    do: EDA.API.Member.list(guild_id, opts) |> parse_members(guild_id)

  @doc "Searches a guild's members whose username or nickname starts with `query`. Takes `:limit`."
  @spec search(String.t() | integer(), String.t(), keyword()) :: {:ok, [t()]} | {:error, term()}
  def search(guild_id, query, opts \\ []),
    do: EDA.API.Member.search(guild_id, query, opts) |> parse_members(guild_id)

  @doc "A lazy stream of every member of a guild. Takes the options of `EDA.API.Member.stream/2`."
  @spec stream(String.t() | integer(), keyword()) :: Enumerable.t()
  def stream(guild_id, opts \\ []) do
    guild_id
    |> EDA.API.Member.stream(opts)
    |> Stream.map(&%{from_raw(&1) | guild_id: to_string(guild_id)})
  end

  @doc "Moves a member to another voice channel, or disconnects them with `nil`."
  @spec move_voice(String.t() | integer(), t() | String.t() | integer(), String.t() | nil) ::
          {:ok, t()} | {:error, term()}
  def move_voice(guild_id, %__MODULE__{user: %{id: uid}}, channel_id),
    do: move_voice(guild_id, uid, channel_id)

  def move_voice(guild_id, user_id, channel_id) do
    EDA.API.Member.move_voice(guild_id, user_id, channel_id)
    |> parse_response()
    |> put_guild(guild_id)
  end

  defp parse_members({:ok, list}, guild_id) when is_list(list),
    do: {:ok, Enum.map(list, &%{from_raw(&1) | guild_id: to_string(guild_id)})}

  defp parse_members({:error, _} = err, _guild_id), do: err
end
