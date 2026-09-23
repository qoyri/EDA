defmodule EDA.Guild do
  @moduledoc """
  A Discord guild — a server.

  Every field of Discord's guild object is kept: `features`, the boost level
  (`premium_tier`, `premium_subscription_count`), the images (`icon`, `banner`, `splash`,
  `discovery_splash`), `vanity_url_code`, the system, rules, updates and safety channels, the
  moderation levels, `preferred_locale`, the limits, and more. Enumerations and flags are the
  integers Discord sends.

  ## What only arrives with `GUILD_CREATE`

  `joined_at`, `large`, `member_count`, `channels`, `threads`, `members`, `voice_states`,
  `presences`, `stage_instances`, `guild_scheduled_events` and `soundboard_sounds` come only
  with the guild the gateway sends when the bot joins it or starts up. They describe that moment
  and are `nil` on a guild read from the cache or the REST API: the cache keeps each of them in
  its own table, up to date — `EDA.Cache.channels_for_guild/1`, `EDA.Cache.members/1`,
  `EDA.Cache.voice_states/1`, `EDA.Cache.presences/1`.

  `roles`, `emojis` and `stickers` are part of the guild object, and `fetch/1` reads the roles
  from their own cache, so they are current.
  """
  use EDA.Event.Access

  # There is one guild struct per guild, so a map past its compact form costs nothing held in
  # bulk; its fields stay flat, as Discord sends them. The limit matters for what the cache holds by the
  # thousand; see test/eda/cached_struct_size_test.exs.
  # credo:disable-for-next-line Credo.Check.Warning.StructFieldAmount
  defstruct [
    :id,
    :name,
    :icon,
    :icon_hash,
    :splash,
    :discovery_splash,
    :banner,
    :description,
    :owner,
    :owner_id,
    :permissions,
    :features,
    :premium_tier,
    :premium_subscription_count,
    :premium_progress_bar_enabled,
    :vanity_url_code,
    :preferred_locale,
    :verification_level,
    :default_message_notifications,
    :explicit_content_filter,
    :mfa_level,
    :nsfw_level,
    :afk_channel_id,
    :afk_timeout,
    :widget_enabled,
    :widget_channel_id,
    :system_channel_id,
    :system_channel_flags,
    :rules_channel_id,
    :public_updates_channel_id,
    :safety_alerts_channel_id,
    :application_id,
    :max_presences,
    :max_members,
    :max_video_channel_users,
    :max_stage_video_channel_users,
    :approximate_member_count,
    :approximate_presence_count,
    :welcome_screen,
    :incidents_data,
    :roles,
    :emojis,
    :stickers,
    :joined_at,
    :large,
    :unavailable,
    :member_count,
    :channels,
    :threads,
    :members,
    :voice_states,
    :presences,
    :stage_instances,
    :guild_scheduled_events,
    :soundboard_sounds
  ]

  @type t :: %__MODULE__{
          id: String.t() | nil,
          name: String.t() | nil,
          icon: String.t() | nil,
          icon_hash: String.t() | nil,
          splash: String.t() | nil,
          discovery_splash: String.t() | nil,
          banner: String.t() | nil,
          description: String.t() | nil,
          owner: boolean() | nil,
          owner_id: String.t() | nil,
          permissions: String.t() | nil,
          features: [String.t()] | nil,
          premium_tier: non_neg_integer() | nil,
          premium_subscription_count: non_neg_integer() | nil,
          premium_progress_bar_enabled: boolean() | nil,
          vanity_url_code: String.t() | nil,
          preferred_locale: String.t() | nil,
          verification_level: non_neg_integer() | nil,
          default_message_notifications: non_neg_integer() | nil,
          explicit_content_filter: non_neg_integer() | nil,
          mfa_level: non_neg_integer() | nil,
          nsfw_level: non_neg_integer() | nil,
          afk_channel_id: String.t() | nil,
          afk_timeout: non_neg_integer() | nil,
          widget_enabled: boolean() | nil,
          widget_channel_id: String.t() | nil,
          system_channel_id: String.t() | nil,
          system_channel_flags: non_neg_integer() | nil,
          rules_channel_id: String.t() | nil,
          public_updates_channel_id: String.t() | nil,
          safety_alerts_channel_id: String.t() | nil,
          application_id: String.t() | nil,
          max_presences: non_neg_integer() | nil,
          max_members: non_neg_integer() | nil,
          max_video_channel_users: non_neg_integer() | nil,
          max_stage_video_channel_users: non_neg_integer() | nil,
          approximate_member_count: non_neg_integer() | nil,
          approximate_presence_count: non_neg_integer() | nil,
          welcome_screen: map() | nil,
          incidents_data: map() | nil,
          roles: [EDA.Role.t()] | nil,
          emojis: [EDA.Emoji.t()] | nil,
          stickers: [EDA.Sticker.t()] | nil,
          joined_at: DateTime.t() | nil,
          large: boolean() | nil,
          unavailable: boolean() | nil,
          member_count: non_neg_integer() | nil,
          channels: [EDA.Channel.t()] | nil,
          threads: [EDA.Channel.t()] | nil,
          members: [EDA.Member.t()] | nil,
          voice_states: [EDA.VoiceState.t()] | nil,
          presences: [map()] | nil,
          stage_instances: [map()] | nil,
          guild_scheduled_events: [map()] | nil,
          soundboard_sounds: [EDA.SoundboardSound.t()] | nil
        }

  @spec from_raw(map()) :: t()
  def from_raw(raw) when is_map(raw) do
    %__MODULE__{
      id: raw["id"],
      name: raw["name"],
      icon: raw["icon"],
      icon_hash: raw["icon_hash"],
      splash: raw["splash"],
      discovery_splash: raw["discovery_splash"],
      banner: raw["banner"],
      description: raw["description"],
      owner: raw["owner"],
      owner_id: raw["owner_id"],
      permissions: raw["permissions"],
      features: raw["features"],
      premium_tier: raw["premium_tier"],
      premium_subscription_count: raw["premium_subscription_count"],
      premium_progress_bar_enabled: raw["premium_progress_bar_enabled"],
      vanity_url_code: raw["vanity_url_code"],
      # The partial guild of an interaction names it `locale`.
      preferred_locale: raw["preferred_locale"] || raw["locale"],
      verification_level: raw["verification_level"],
      default_message_notifications: raw["default_message_notifications"],
      explicit_content_filter: raw["explicit_content_filter"],
      mfa_level: raw["mfa_level"],
      nsfw_level: raw["nsfw_level"],
      afk_channel_id: raw["afk_channel_id"],
      afk_timeout: raw["afk_timeout"],
      widget_enabled: raw["widget_enabled"],
      widget_channel_id: raw["widget_channel_id"],
      system_channel_id: raw["system_channel_id"],
      system_channel_flags: raw["system_channel_flags"],
      rules_channel_id: raw["rules_channel_id"],
      public_updates_channel_id: raw["public_updates_channel_id"],
      safety_alerts_channel_id: raw["safety_alerts_channel_id"],
      application_id: raw["application_id"],
      max_presences: raw["max_presences"],
      max_members: raw["max_members"],
      max_video_channel_users: raw["max_video_channel_users"],
      max_stage_video_channel_users: raw["max_stage_video_channel_users"],
      approximate_member_count: raw["approximate_member_count"],
      approximate_presence_count: raw["approximate_presence_count"],
      welcome_screen: raw["welcome_screen"],
      incidents_data: raw["incidents_data"],
      roles: parse_list(raw["roles"], &EDA.Role.from_raw/1),
      emojis: parse_list(raw["emojis"], &EDA.Emoji.from_raw/1),
      stickers: parse_list(raw["stickers"], &EDA.Sticker.from_raw/1),
      joined_at: EDA.Timestamp.parse(raw["joined_at"]),
      large: raw["large"],
      unavailable: raw["unavailable"],
      member_count: raw["member_count"],
      channels: parse_list(raw["channels"], &EDA.Channel.from_raw/1),
      threads: parse_list(raw["threads"], &EDA.Channel.from_raw/1),
      members: parse_list(raw["members"], &EDA.Member.from_raw/1),
      voice_states: parse_list(raw["voice_states"], &EDA.VoiceState.from_raw/1),
      presences: raw["presences"],
      stage_instances: raw["stage_instances"],
      guild_scheduled_events: raw["guild_scheduled_events"],
      soundboard_sounds: parse_list(raw["soundboard_sounds"], &EDA.SoundboardSound.from_raw/1)
    }
  end

  @doc false
  # What GUILD_CREATE carries besides the guild object, and the cache keeps elsewhere.
  def gateway_lists,
    do: ~w(channels threads members voice_states presences stage_instances
           guild_scheduled_events soundboard_sounds)

  # A guild always has @everyone, so no role at all means the role cache is off: say nil rather
  # than an empty list.
  defp with_cached_roles(raw, guild_id) do
    case EDA.Cache.roles(guild_id) do
      [] -> raw
      roles -> Map.put(raw, "roles", roles)
    end
  end

  defp parse_list(nil, _parse), do: nil
  defp parse_list(list, parse) when is_list(list), do: Enum.map(list, parse)

  # ── Entity Manager ──

  use EDA.Entity

  @doc """
  Fetches a guild by ID. Checks cache first, falls back to REST.

  Accepts a guild struct or a string/integer ID.
  """
  @spec fetch(t() | String.t() | integer()) :: {:ok, t()} | {:error, term()}
  def fetch(%__MODULE__{id: id}), do: fetch(id)

  def fetch(guild_id) do
    case EDA.Cache.get_guild(guild_id) do
      nil -> EDA.API.Guild.get(guild_id) |> parse_response()
      raw -> {:ok, from_raw(with_cached_roles(raw, guild_id))}
    end
  end

  @doc """
  Fetches a guild by ID. Raises on error.
  """
  @spec fetch!(t() | String.t() | integer()) :: t()
  def fetch!(guild_id) do
    case fetch(guild_id) do
      {:ok, guild} -> guild
      {:error, reason} -> raise "Failed to fetch guild: #{inspect(reason)}"
    end
  end

  @doc """
  Modifies a guild. Accepts a struct or ID, a map of changes, and options.

  ## Options

  - `:reason` - Audit log reason
  """
  @spec modify(t() | String.t() | integer(), map(), keyword()) :: {:ok, t()} | {:error, term()}
  def modify(guild, payload, opts \\ [])
  def modify(%__MODULE__{id: id}, payload, opts), do: modify(id, payload, opts)

  def modify(guild_id, payload, opts) when is_binary(guild_id) or is_integer(guild_id) do
    EDA.API.Guild.modify(guild_id, payload, opts) |> parse_response()
  end

  @doc """
  Applies a changeset to a guild. No-op if the changeset has no changes.

  ## Options

  - `:reason` - Audit log reason
  """
  @spec apply_changeset(Changeset.t(), keyword()) :: {:ok, t()} | {:error, term()}
  def apply_changeset(changeset, opts \\ [])

  def apply_changeset(%Changeset{module: __MODULE__, entity: entity} = cs, opts) do
    if Changeset.changed?(cs) do
      modify(entity, Changeset.changes(cs), opts)
    else
      {:ok, entity}
    end
  end

  @doc """
  Deletes a guild. The bot must be the owner.
  """
  @spec delete(t() | String.t() | integer()) :: :ok | {:error, term()}
  def delete(%__MODULE__{id: id}), do: delete(id)

  def delete(guild_id) do
    EDA.HTTP.Client.delete("/guilds/#{guild_id}") |> parse_response()
  end

  @doc """
  Makes the bot leave a guild. Discord then sends `GUILD_DELETE`. The bot cannot leave a guild
  it owns.
  """
  @spec leave(t() | String.t() | integer()) :: :ok | {:error, term()}
  def leave(%__MODULE__{id: id}), do: leave(id)
  def leave(guild_id), do: EDA.API.User.leave_guild(guild_id)

  @doc """
  Gets channels for a guild, returned as `%EDA.Channel{}` structs.
  """
  @spec channels(t() | String.t() | integer()) :: {:ok, [EDA.Channel.t()]} | {:error, term()}
  def channels(%__MODULE__{id: id}), do: channels(id)

  def channels(guild_id) do
    case EDA.API.Guild.channels(guild_id) do
      {:ok, list} -> {:ok, Enum.map(list, &EDA.Channel.from_raw/1)}
      {:error, _} = err -> err
    end
  end

  @doc """
  Returns the CDN URL for the guild's icon, or `nil` if the guild has no icon.

  An animated icon comes as a GIF unless another format is asked for.

  ## Options

  - `:format` — `:png`, `:jpg`, `:webp` or `:gif`. Defaults to `:gif` when the image is animated
    and `:png` otherwise; `:webp` of an animated image stays animated (Discord recommends it for
    animated images). `:gif` of a still image raises, since Discord answers 415
  - `:size` — a power of two from 16 to 4096
  - `:animated` — `false` for the still of an animated image

  ## Examples

      iex> EDA.Guild.icon_url(%EDA.Guild{id: "123", icon: "abc"})
      "https://cdn.discordapp.com/icons/123/abc.png"

      iex> EDA.Guild.icon_url(%EDA.Guild{id: "123", icon: "a_abc"}, format: :webp, size: 64)
      "https://cdn.discordapp.com/icons/123/a_abc.webp?size=64&animated=true"
  """
  @spec icon_url(t(), keyword()) :: String.t() | nil
  def icon_url(guild, opts \\ [])
  def icon_url(%__MODULE__{icon: nil}, _opts), do: nil

  def icon_url(%__MODULE__{id: id, icon: icon}, opts),
    do: EDA.CDN.url("icons/#{id}/#{icon}", EDA.CDN.animated_hash?(icon), opts)
end
