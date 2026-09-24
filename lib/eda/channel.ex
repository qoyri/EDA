defmodule EDA.Channel do
  @moduledoc """
  Represents a Discord channel.

  ## Channel types

  `type` is an atom, Discord's name for it in lowercase; a type Discord adds before EDA knows it
  stays the integer. Every call that takes a channel type accepts the atom or the integer, and
  `type_value/1` converts.

  | `type`                   | Value | Description                          |
  |--------------------------|-------|--------------------------------------|
  | `:guild_text`            | 0     | Text channel in a guild              |
  | `:dm`                    | 1     | Direct message                       |
  | `:guild_voice`           | 2     | Voice channel in a guild             |
  | `:group_dm`              | 3     | Group DM                             |
  | `:guild_category`        | 4     | Category                             |
  | `:guild_announcement`    | 5     | Announcement channel                 |
  | `:announcement_thread`   | 10    | Thread in an announcement channel    |
  | `:public_thread`         | 11    | Public thread                        |
  | `:private_thread`        | 12    | Private thread                       |
  | `:guild_stage_voice`     | 13    | Stage channel                        |
  | `:guild_directory`       | 14    | Student hub directory                |
  | `:guild_forum`           | 15    | Forum channel                        |
  | `:guild_media`           | 16    | Media channel                        |

  The `type_*/0` functions return the integers, for code written against them.

  ## Forum layout types

  | Constant              | Value | Description   |
  |-----------------------|-------|---------------|
  | `layout_not_set/0`    | 0     | Not set       |
  | `layout_list_view/0`  | 1     | List view     |
  | `layout_gallery_view/0`| 2    | Gallery view  |

  ## Sort order types

  | Constant                | Value | Description       |
  |-------------------------|-------|-------------------|
  | `sort_latest_activity/0`| 0     | Latest activity   |
  | `sort_creation_date/0`  | 1     | Creation date     |
  """

  import Bitwise

  use EDA.Event.Access

  # ── Channel types ──

  @type_guild_text 0
  @type_dm 1
  @type_guild_voice 2
  @type_group_dm 3
  @type_guild_category 4
  @type_guild_news 5
  @type_guild_news_thread 10
  @type_guild_public_thread 11
  @type_guild_private_thread 12
  @type_guild_stage_voice 13
  @type_guild_forum 15
  @type_guild_media 16

  @types %{
    0 => :guild_text,
    1 => :dm,
    2 => :guild_voice,
    3 => :group_dm,
    4 => :guild_category,
    5 => :guild_announcement,
    10 => :announcement_thread,
    11 => :public_thread,
    12 => :private_thread,
    13 => :guild_stage_voice,
    14 => :guild_directory,
    15 => :guild_forum,
    16 => :guild_media
  }

  @type channel_type ::
          :guild_text
          | :dm
          | :guild_voice
          | :group_dm
          | :guild_category
          | :guild_announcement
          | :announcement_thread
          | :public_thread
          | :private_thread
          | :guild_stage_voice
          | :guild_directory
          | :guild_forum
          | :guild_media
          | integer()

  @thread_types [@type_guild_news_thread, @type_guild_public_thread, @type_guild_private_thread]
  @forum_types [@type_guild_forum, @type_guild_media]
  @voice_types [@type_guild_voice, @type_guild_stage_voice]
  @dm_types [@type_dm, @type_group_dm]

  # ── Forum layout ──

  @layout_not_set 0
  @layout_list_view 1
  @layout_gallery_view 2

  # ── Sort order ──

  @sort_latest_activity 0
  @sort_creation_date 1

  defstruct [
    :id,
    :type,
    :guild_id,
    :position,
    :permission_overwrites,
    :name,
    :topic,
    :nsfw,
    :rate_limit_per_user,
    :parent_id,
    :last_message_id,
    :last_pin_timestamp,
    :permissions,
    :app_permissions,
    :default_auto_archive_duration,
    :default_thread_rate_limit_per_user,
    :flags,
    :owner_id,
    :thread,
    :forum,
    :voice,
    :dm
  ]

  @type t :: %__MODULE__{
          id: String.t() | nil,
          type: channel_type() | nil,
          guild_id: String.t() | nil,
          position: integer() | nil,
          permission_overwrites: [EDA.PermissionOverwrite.t()] | nil,
          name: String.t() | nil,
          topic: String.t() | nil,
          nsfw: boolean() | nil,
          rate_limit_per_user: integer() | nil,
          parent_id: String.t() | nil,
          last_message_id: String.t() | nil,
          last_pin_timestamp: DateTime.t() | nil,
          permissions: String.t() | nil,
          app_permissions: String.t() | nil,
          default_auto_archive_duration: integer() | nil,
          default_thread_rate_limit_per_user: integer() | nil,
          flags: integer() | nil,
          owner_id: String.t() | nil,
          thread: EDA.Channel.Thread.t() | nil,
          forum: EDA.Channel.Forum.t() | nil,
          voice: EDA.Channel.Voice.t() | nil,
          dm: EDA.Channel.DM.t() | nil
        }

  # ── Channel type accessors ──

  @doc "Returns `0` — Guild text channel."
  def type_guild_text, do: @type_guild_text

  @doc "Returns `1` — Direct message."
  def type_dm, do: @type_dm

  @doc "Returns `2` — Guild voice channel."
  def type_guild_voice, do: @type_guild_voice

  @doc "Returns `3` — Group DM."
  def type_group_dm, do: @type_group_dm

  @doc "Returns `4` — Guild category."
  def type_guild_category, do: @type_guild_category

  @doc "Returns `5` — Guild news/announcement channel."
  def type_guild_news, do: @type_guild_news

  @doc "Returns `10` — Thread in a news channel."
  def type_guild_news_thread, do: @type_guild_news_thread

  @doc "Returns `11` — Public thread."
  def type_guild_public_thread, do: @type_guild_public_thread

  @doc "Returns `12` — Private thread."
  def type_guild_private_thread, do: @type_guild_private_thread

  @doc "Returns `13` — Stage voice channel."
  def type_guild_stage_voice, do: @type_guild_stage_voice

  @doc "Returns `15` — Forum channel."
  def type_guild_forum, do: @type_guild_forum

  @doc "Returns `16` — Media channel."
  def type_guild_media, do: @type_guild_media

  # ── Layout accessors ──

  @doc "Returns `0` — Forum layout not set."
  def layout_not_set, do: @layout_not_set

  @doc "Returns `1` — List view layout."
  def layout_list_view, do: @layout_list_view

  @doc "Returns `2` — Gallery view layout."
  def layout_gallery_view, do: @layout_gallery_view

  # ── Sort order accessors ──

  @doc "Returns `0` — Sort by latest activity."
  def sort_latest_activity, do: @sort_latest_activity

  @doc "Returns `1` — Sort by creation date."
  def sort_creation_date, do: @sort_creation_date

  # ── Flags ──

  @flag_pinned 1 <<< 1
  @flag_require_tag 1 <<< 4
  @flag_hide_media_download_options 1 <<< 15
  @flag_obfuscated 1 <<< 17
  @flag_spoiler 1 <<< 21

  @channel_flags %{
    pinned: @flag_pinned,
    require_tag: @flag_require_tag,
    hide_media_download_options: @flag_hide_media_download_options,
    obfuscated: @flag_obfuscated,
    spoiler: @flag_spoiler
  }

  @obfuscated_name "___hidden___"

  @typedoc "A channel flag name."
  @type flag ::
          :pinned | :require_tag | :hide_media_download_options | :obfuscated | :spoiler

  @doc "Thread pinned in its parent forum or media channel (`1 <<< 1`)."
  @spec flag_pinned() :: integer()
  def flag_pinned, do: @flag_pinned

  @doc "Threads in this forum or media channel require a tag (`1 <<< 4`)."
  @spec flag_require_tag() :: integer()
  def flag_require_tag, do: @flag_require_tag

  @doc "Hides embedded media download options; media channels only (`1 <<< 15`)."
  @spec flag_hide_media_download_options() :: integer()
  def flag_hide_media_download_options, do: @flag_hide_media_download_options

  @doc "The channel's metadata is obfuscated because the bot cannot view it (`1 <<< 17`)."
  @spec flag_obfuscated() :: integer()
  def flag_obfuscated, do: @flag_obfuscated

  @doc "The channel requires opt-in viewing (`1 <<< 21`)."
  @spec flag_spoiler() :: integer()
  def flag_spoiler, do: @flag_spoiler

  @doc """
  The `name` Discord substitutes for an obfuscated channel.

  ## Examples

      iex> EDA.Channel.obfuscated_name()
      "___hidden___"
  """
  @spec obfuscated_name() :: String.t()
  def obfuscated_name, do: @obfuscated_name

  @doc "Every flag name EDA knows about."
  @spec all_flags() :: [flag()]
  def all_flags, do: Map.keys(@channel_flags)

  @doc """
  Returns `true` if the given flag is set.

  Accepts a `t:t/0`, a raw channel map as the cache stores it, a bitfield, or `nil`.

  ## Examples

      iex> EDA.Channel.has_flag?(%EDA.Channel{flags: 1 <<< 17}, :obfuscated)
      true

      iex> EDA.Channel.has_flag?(%{"flags" => 0}, :obfuscated)
      false

      iex> EDA.Channel.has_flag?(nil, :obfuscated)
      false
  """
  @spec has_flag?(t() | map() | integer() | nil, flag()) :: boolean()
  def has_flag?(channel, flag)

  def has_flag?(%__MODULE__{flags: flags}, flag), do: has_flag?(flags, flag)
  def has_flag?(%{"flags" => flags}, flag), do: has_flag?(flags, flag)

  def has_flag?(bitfield, flag) when is_integer(bitfield) do
    case Map.get(@channel_flags, flag) do
      nil -> false
      value -> (bitfield &&& value) == value
    end
  end

  def has_flag?(_channel, _flag), do: false

  @doc """
  Returns the set flags as a list of names, ignoring bits EDA does not know.

  ## Examples

      iex> EDA.Channel.flag_list(%EDA.Channel{flags: (1 <<< 17) + (1 <<< 1)})
      [:obfuscated, :pinned]

      iex> EDA.Channel.flag_list(nil)
      []
  """
  @spec flag_list(t() | map() | integer() | nil) :: [flag()]
  def flag_list(channel)

  def flag_list(%__MODULE__{flags: flags}), do: flag_list(flags)
  def flag_list(%{"flags" => flags}), do: flag_list(flags)

  def flag_list(bitfield) when is_integer(bitfield) do
    @channel_flags
    |> Enum.filter(fn {_name, value} -> (bitfield &&& value) == value end)
    |> Enum.map(&elem(&1, 0))
    |> Enum.sort()
  end

  def flag_list(_channel), do: []

  @doc """
  Returns `true` if Discord has obfuscated this channel because the bot cannot view it.

  Obfuscated channels are still dispatched over the gateway, but their metadata is
  redacted: `name` becomes `#{@obfuscated_name}`, sensitive fields are nulled, and
  `permission_overwrites` holds a single overwrite denying `VIEW_CHANNEL` to the
  guild's `@everyone` role. Treat them as "exists but invisible" — in particular do
  not compute permissions from those overwrites, and consider filtering them out of
  channel listings shown to users.

  Mandatory for every bot from **2026-11-16**; before then it is opt-in via
  `config :eda, capabilities: [:channel_obfuscation]` (see `EDA.Gateway.Capabilities`).

  ## Examples

      iex> EDA.Channel.obfuscated?(%EDA.Channel{flags: 1 <<< 17})
      true

      iex> EDA.Channel.obfuscated?(%EDA.Channel{flags: 0})
      false

      iex> EDA.Channel.obfuscated?(%{"flags" => 1 <<< 17})
      true

      iex> EDA.Channel.obfuscated?(nil)
      false
  """
  @spec obfuscated?(t() | map() | integer() | nil) :: boolean()
  def obfuscated?(channel), do: has_flag?(channel, :obfuscated)

  # ── Type helpers ──

  @doc """
  Returns `true` if the channel is a forum channel.

  ## Examples

      iex> EDA.Channel.forum?(%EDA.Channel{type: :guild_forum})
      true

      iex> EDA.Channel.forum?(%EDA.Channel{type: :guild_text})
      false
  """
  @spec forum?(t()) :: boolean()
  def forum?(%__MODULE__{type: type}), do: type == :guild_forum

  @doc """
  Returns `true` if the channel is a media channel.

  ## Examples

      iex> EDA.Channel.media?(%EDA.Channel{type: :guild_media})
      true

      iex> EDA.Channel.media?(%EDA.Channel{type: :guild_text})
      false
  """
  @spec media?(t()) :: boolean()
  def media?(%__MODULE__{type: type}), do: type == :guild_media

  @doc """
  Returns `true` if the channel is a thread.

  ## Examples

      iex> EDA.Channel.thread?(%EDA.Channel{type: :public_thread})
      true

      iex> EDA.Channel.thread?(%EDA.Channel{type: :guild_text})
      false
  """
  @spec thread?(t()) :: boolean()
  def thread?(%__MODULE__{type: type}),
    do: type in [:announcement_thread, :public_thread, :private_thread]

  @doc """
  Whether messages can be sent in the channel's own chat: a text, announcement or DM channel,
  or a thread. Voice and stage channels also have a chat; see `voice?/1`.

      iex> EDA.Channel.text?(%EDA.Channel{type: :guild_announcement})
      true
  """
  @spec text?(t()) :: boolean()
  def text?(%__MODULE__{type: type} = channel),
    do: type in [:guild_text, :guild_announcement, :dm, :group_dm] or thread?(channel)

  @doc "Whether the channel is a voice or stage channel."
  @spec voice?(t()) :: boolean()
  def voice?(%__MODULE__{type: type}), do: type in [:guild_voice, :guild_stage_voice]

  @doc "Whether the channel is a category."
  @spec category?(t()) :: boolean()
  def category?(%__MODULE__{type: type}), do: type == :guild_category

  @doc "Whether the channel is a DM or a group DM."
  @spec dm?(t()) :: boolean()
  def dm?(%__MODULE__{type: type}), do: type in [:dm, :group_dm]

  @doc "Whether the thread is archived; `false` for a channel that is not a thread."
  @spec archived?(t()) :: boolean()
  def archived?(%__MODULE__{thread: %{archived: archived}}), do: archived == true
  def archived?(%__MODULE__{}), do: false

  @doc "Whether the thread is locked: only moderators can unarchive it."
  @spec locked?(t()) :: boolean()
  def locked?(%__MODULE__{thread: %{locked: locked}}), do: locked == true
  def locked?(%__MODULE__{}), do: false

  @doc """
  The channel's link.

      iex> EDA.Channel.url(%EDA.Channel{id: "2", guild_id: "1"})
      "https://discord.com/channels/1/2"
  """
  @spec url(t()) :: String.t()
  def url(%__MODULE__{id: id, guild_id: guild_id}),
    do: "https://discord.com/channels/#{guild_id || "@me"}/#{id}"

  @doc """
  The channels in a category, from the cache, by position.
  """
  @spec children(t()) :: [t()]
  def children(%__MODULE__{id: id, guild_id: guild_id}) when is_binary(guild_id) do
    guild_id
    |> EDA.Cache.channels_for_guild()
    |> Enum.filter(&(&1["parent_id"] == id))
    |> Enum.map(&from_raw/1)
    |> Enum.sort_by(&{&1.position || 0, &1.id})
  end

  def children(%__MODULE__{}), do: []

  @doc """
  The integer Discord uses for a channel type, from its atom or the integer itself.

      iex> EDA.Channel.type_value(:guild_forum)
      15

      iex> EDA.Channel.type_value(15)
      15
  """
  @spec type_value(channel_type() | nil) :: integer() | nil
  def type_value(type), do: EDA.Enum.value!(@types, type, "channel type")

  @doc """
  The atom for a channel type's integer; one EDA does not know stays the integer.

      iex> EDA.Channel.type_name(5)
      :guild_announcement

      iex> EDA.Channel.type_name(99)
      99
  """
  @spec type_name(integer() | nil) :: channel_type() | nil
  def type_name(value), do: EDA.Enum.name(@types, value)

  # ── Parsing ──

  @spec from_raw(map()) :: t()
  def from_raw(%__MODULE__{} = parsed), do: parsed

  def from_raw(raw) when is_map(raw) do
    %__MODULE__{
      id: :maps.get("id", raw, nil),
      type: EDA.Enum.name(@types, :maps.get("type", raw, nil)),
      guild_id: :maps.get("guild_id", raw, nil),
      position: :maps.get("position", raw, nil),
      permission_overwrites: parse_overwrites(:maps.get("permission_overwrites", raw, nil)),
      name: :maps.get("name", raw, nil),
      topic: :maps.get("topic", raw, nil),
      nsfw: :maps.get("nsfw", raw, nil),
      rate_limit_per_user: :maps.get("rate_limit_per_user", raw, nil),
      parent_id: :maps.get("parent_id", raw, nil),
      last_message_id: :maps.get("last_message_id", raw, nil),
      last_pin_timestamp: EDA.Timestamp.parse(:maps.get("last_pin_timestamp", raw, nil)),
      permissions: :maps.get("permissions", raw, nil),
      app_permissions: :maps.get("app_permissions", raw, nil),
      default_auto_archive_duration: :maps.get("default_auto_archive_duration", raw, nil),
      default_thread_rate_limit_per_user:
        :maps.get("default_thread_rate_limit_per_user", raw, nil),
      flags: :maps.get("flags", raw, nil),
      owner_id: :maps.get("owner_id", raw, nil),
      thread: kind(raw, @thread_types, EDA.Channel.Thread),
      forum: kind(raw, @forum_types, EDA.Channel.Forum),
      voice: kind(raw, @voice_types, EDA.Channel.Voice),
      dm: kind(raw, @dm_types, EDA.Channel.DM)
    }
  end

  # A channel of the kind gets its part, as does one whose type is missing but whose payload
  # carries that kind's fields — partial channels, such as a thread in a message, may lack a type.
  defp kind(%{"type" => type} = raw, types, mod) when is_integer(type) do
    if type in types, do: mod.from_raw(raw)
  end

  defp kind(raw, _types, mod) do
    if Enum.any?(mod.raw_keys(), &Map.has_key?(raw, &1)), do: mod.from_raw(raw)
  end

  @doc """
  Applies a partial update from Discord to the channel: `EDA.Entity.patch/2`, with the parts of
  a thread, forum, voice or DM channel updated from the keys they are read from.
  """
  @spec patch(t(), map()) :: t()
  def patch(%__MODULE__{} = channel, raw) when is_map(raw) do
    patched = EDA.Entity.patch_fields(channel, raw)

    Enum.reduce(
      [
        thread: EDA.Channel.Thread,
        forum: EDA.Channel.Forum,
        voice: EDA.Channel.Voice,
        dm: EDA.Channel.DM
      ],
      patched,
      fn {field, mod}, acc -> patch_part(acc, field, mod, raw) end
    )
  end

  defp patch_part(channel, field, mod, raw) do
    cond do
      not Enum.any?(mod.raw_keys(), &Map.has_key?(raw, &1)) ->
        channel

      # A thread's metadata comes nested and whole; the other parts keep Discord's own keys.
      field == :thread or is_nil(Map.fetch!(channel, field)) ->
        Map.put(channel, field, mod.from_raw(raw))

      true ->
        Map.put(channel, field, EDA.Entity.patch_fields(Map.fetch!(channel, field), raw))
    end
  end

  defp parse_overwrites(nil), do: nil

  defp parse_overwrites(list) when is_list(list),
    do: Enum.map(list, &EDA.PermissionOverwrite.from_raw/1)

  # ── Entity Manager ──

  use EDA.Entity

  @doc """
  Fetches a channel by ID. Checks cache first, falls back to REST.
  """
  @spec fetch(t() | String.t() | integer()) :: {:ok, t()} | {:error, term()}
  def fetch(%__MODULE__{id: id}), do: fetch(id)

  def fetch(channel_id) do
    case EDA.Cache.get_channel(channel_id) do
      nil -> EDA.API.Channel.get(channel_id) |> parse_response()
      channel -> {:ok, channel}
    end
  end

  @doc """
  Fetches a channel by ID. Raises on error.
  """
  @spec fetch!(t() | String.t() | integer()) :: t()
  def fetch!(channel_id) do
    case fetch(channel_id) do
      {:ok, channel} -> channel
      {:error, reason} -> raise "Failed to fetch channel: #{inspect(reason)}"
    end
  end

  @doc """
  Modifies a channel. Accepts a struct or ID, a map of changes, and options.

  ## Options

  - `:reason` - Audit log reason
  """
  @spec modify(t() | String.t() | integer(), map(), keyword()) :: {:ok, t()} | {:error, term()}
  def modify(channel, payload, opts \\ [])
  def modify(%__MODULE__{id: id}, payload, opts), do: modify(id, payload, opts)

  def modify(channel_id, payload, opts) when is_binary(channel_id) or is_integer(channel_id) do
    EDA.API.Channel.modify(channel_id, payload, opts) |> parse_response()
  end

  @doc """
  Applies a changeset to a channel. No-op if the changeset has no changes.

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
  Deletes a channel.

  ## Options

  - `:reason` - Audit log reason
  """
  @spec delete(t() | String.t() | integer(), keyword()) :: :ok | {:error, term()}
  def delete(channel, opts \\ [])
  def delete(%__MODULE__{id: id}, opts), do: delete(id, opts)

  def delete(channel_id, opts) when is_binary(channel_id) or is_integer(channel_id) do
    EDA.API.Channel.delete(channel_id, opts) |> parse_response()
  end

  @doc """
  Sends a message to a channel. Returns a `%EDA.Message{}` struct.
  """
  @spec send_message(t() | String.t() | integer(), String.t() | map() | keyword()) ::
          {:ok, EDA.Message.t()} | {:error, term()}
  def send_message(%__MODULE__{id: id}, content), do: send_message(id, content)

  def send_message(channel_id, content) do
    case EDA.API.Message.create(channel_id, content) do
      {:ok, raw} when is_map(raw) -> {:ok, EDA.Message.from_raw(raw)}
      {:error, _} = err -> err
    end
  end

  @doc """
  Sets a voice channel's status (up to 500 characters, or `nil` to clear it).

  Accepts a channel struct or ID.

  ## Options

  - `:reason` - Audit log reason
  """
  @spec set_voice_status(t() | String.t() | integer(), String.t() | nil, keyword()) ::
          :ok | {:error, term()}
  def set_voice_status(channel, status, opts \\ [])

  def set_voice_status(%__MODULE__{id: id}, status, opts),
    do: set_voice_status(id, status, opts)

  def set_voice_status(channel_id, status, opts)
      when is_binary(channel_id) or is_integer(channel_id) do
    EDA.API.Channel.set_voice_status(channel_id, status, opts)
  end

  @info_fields [:status, :voice_start_time]

  @doc """
  Asks the gateway for a guild's ephemeral channel data (opcode 43): voice channel statuses and
  voice session start times, which are not part of the channel object.

  The answer arrives as a `CHANNEL_INFO` event — `EDA.Event.ChannelInfo`. Returns `:ok` once the
  request is sent; it does not wait for the answer. Changes after that arrive as
  `VOICE_CHANNEL_STATUS_UPDATE` and `VOICE_CHANNEL_START_TIME_UPDATE`.

      EDA.Channel.request_info(guild_id)
      EDA.Channel.request_info(guild_id, [:status])
  """
  @spec request_info(String.t() | integer(), [:status | :voice_start_time]) :: :ok
  def request_info(guild_id, fields \\ @info_fields) when is_list(fields) do
    case fields -- @info_fields do
      [] ->
        EDA.Gateway.Connection.request_channel_info(
          to_string(guild_id),
          Enum.map(fields, &to_string/1)
        )

      unknown ->
        raise ArgumentError,
              "channel info fields are #{inspect(@info_fields)}, got #{inspect(unknown)}"
    end
  end

  @doc """
  Follows an announcement channel, posting its published messages to `target`. Returns the
  webhook Discord created there, `%{"channel_id" => ..., "webhook_id" => ...}`.

  ## Options

    * `:reason` — audit log reason
  """
  @spec follow(t() | String.t() | integer(), t() | String.t() | integer(), keyword()) ::
          {:ok, map()} | {:error, term()}
  def follow(channel, target, opts \\ [])
  def follow(%__MODULE__{id: id}, target, opts), do: follow(id, target, opts)
  def follow(channel_id, %__MODULE__{id: id}, opts), do: follow(channel_id, id, opts)
  def follow(channel_id, target_id, opts), do: EDA.API.Channel.follow(channel_id, target_id, opts)

  # ── Creation and threads ──

  @doc """
  Creates a channel in a guild. Takes the payload of `EDA.API.Channel.create/3` (`:name`,
  `:type` as an atom, `:parent_id`…) and `:reason`.
  """
  @spec create(String.t() | integer(), map(), keyword()) :: {:ok, t()} | {:error, term()}
  def create(guild_id, payload, opts \\ []),
    do: EDA.API.Channel.create(guild_id, payload, opts) |> parse_response()

  @doc """
  Starts a thread: from a message when given an `EDA.Message`, or on its own in a channel.
  Takes `:name`, `:auto_archive_duration` and, without a message, `:type` and `:invitable`.
  """
  @spec start_thread(EDA.Message.t() | t() | String.t() | integer(), map() | keyword()) ::
          {:ok, t()} | {:error, term()}
  def start_thread(%EDA.Message{channel_id: cid, id: mid}, opts),
    do: EDA.API.Thread.start_from_message(cid, mid, opts) |> parse_response()

  def start_thread(channel, opts),
    do: EDA.API.Thread.start(id_of(channel), opts) |> parse_response()

  @doc """
  Creates a post in a forum or media channel: a thread with its first message. Takes the
  thread's options (`:name`, `:applied_tags`…) and the message's, as
  `EDA.API.Thread.create_post/3` does.
  """
  @spec create_post(t() | String.t() | integer(), keyword(), keyword()) ::
          {:ok, t()} | {:error, term()}
  def create_post(forum, opts, message_opts \\ []),
    do: EDA.API.Thread.create_post(id_of(forum), opts, message_opts) |> parse_response()

  @doc "A user's membership of a thread, with their `member` when Discord includes it."
  @spec thread_member(t() | String.t() | integer(), EDA.User.t() | String.t() | integer()) ::
          {:ok, EDA.Channel.ThreadMember.t()} | {:error, term()}
  def thread_member(thread, user) do
    case EDA.API.Thread.get_member(id_of(thread), id_of(user)) do
      {:ok, raw} when is_map(raw) -> {:ok, EDA.Channel.ThreadMember.from_raw(raw)}
      {:error, _} = err -> err
    end
  end

  @doc "The members of a thread."
  @spec thread_members(t() | String.t() | integer()) ::
          {:ok, [EDA.Channel.ThreadMember.t()]} | {:error, term()}
  def thread_members(thread) do
    case EDA.API.Thread.list_members(id_of(thread)) do
      {:ok, list} when is_list(list) ->
        {:ok, Enum.map(list, &EDA.Channel.ThreadMember.from_raw/1)}

      {:error, _} = err ->
        err
    end
  end

  @doc """
  A guild's active threads, with the bot's own membership of those it joined.
  """
  @spec active_threads(String.t() | integer()) ::
          {:ok, %{threads: [t()], members: [EDA.Channel.ThreadMember.t()]}} | {:error, term()}
  def active_threads(guild_id),
    do: EDA.API.Thread.list_active(guild_id) |> parse_threads()

  @doc """
  One page of a channel's archived threads: `kind` is `:public`, `:private` or
  `:joined_private`. Takes `:before` (a `DateTime`, or a thread id for `:joined_private`) and
  `:limit`.
  """
  @spec archived_threads(
          t() | String.t() | integer(),
          :public | :private | :joined_private,
          keyword()
        ) ::
          {:ok, %{threads: [t()], members: [EDA.Channel.ThreadMember.t()], has_more: boolean()}}
          | {:error, term()}
  def archived_threads(channel, kind, opts \\ []) do
    id = id_of(channel)

    case kind do
      :public -> EDA.API.Thread.list_public_archived(id, opts)
      :private -> EDA.API.Thread.list_private_archived(id, opts)
      :joined_private -> EDA.API.Thread.list_joined_private_archived(id, opts)
    end
    |> parse_threads()
  end

  @doc "A lazy stream of a channel's archived threads, page after page. Takes `:per_page`."
  @spec stream_archived_threads(
          t() | String.t() | integer(),
          :public | :private | :joined_private,
          keyword()
        ) :: Enumerable.t()
  def stream_archived_threads(channel, kind, opts \\ []),
    do:
      channel |> id_of() |> EDA.API.Thread.stream_archived(kind, opts) |> Stream.map(&from_raw/1)

  defp parse_threads({:ok, %{"threads" => threads} = raw}) do
    page = %{
      threads: Enum.map(threads, &from_raw/1),
      members: Enum.map(raw["members"] || [], &EDA.Channel.ThreadMember.from_raw/1)
    }

    {:ok,
     if(Map.has_key?(raw, "has_more"), do: Map.put(page, :has_more, raw["has_more"]), else: page)}
  end

  defp parse_threads({:error, _} = err), do: err

  defp id_of(%{id: id}), do: id
  defp id_of(id), do: id
end
