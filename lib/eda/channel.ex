defmodule EDA.Channel do
  @moduledoc """
  Represents a Discord channel.

  ## Channel types

  | Constant                  | Value | Description                    |
  |---------------------------|-------|--------------------------------|
  | `type_guild_text/0`       | 0     | Text channel in a guild        |
  | `type_dm/0`               | 1     | Direct message                 |
  | `type_guild_voice/0`      | 2     | Voice channel in a guild       |
  | `type_group_dm/0`         | 3     | Group DM                       |
  | `type_guild_category/0`   | 4     | Category                       |
  | `type_guild_news/0`       | 5     | News / announcement channel    |
  | `type_guild_news_thread/0`  | 10  | Thread in a news channel       |
  | `type_guild_public_thread/0`| 11  | Public thread                  |
  | `type_guild_private_thread/0`| 12 | Private thread                 |
  | `type_guild_stage_voice/0`| 13    | Stage voice channel            |
  | `type_guild_forum/0`      | 15    | Forum channel                  |
  | `type_guild_media/0`      | 16    | Media channel                  |

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
    :bitrate,
    :user_limit,
    :rate_limit_per_user,
    :parent_id,
    :last_message_id,
    :default_auto_archive_duration,
    :flags,
    :available_tags,
    :applied_tags,
    :default_reaction_emoji,
    :default_thread_rate_limit_per_user,
    :default_sort_order,
    :default_forum_layout,
    :thread_metadata,
    :owner_id,
    :member_count,
    :message_count,
    :total_message_sent,
    :status
  ]

  @type t :: %__MODULE__{
          id: String.t() | nil,
          type: integer() | nil,
          guild_id: String.t() | nil,
          position: integer() | nil,
          permission_overwrites: [EDA.PermissionOverwrite.t()] | nil,
          name: String.t() | nil,
          topic: String.t() | nil,
          nsfw: boolean() | nil,
          bitrate: integer() | nil,
          user_limit: integer() | nil,
          rate_limit_per_user: integer() | nil,
          parent_id: String.t() | nil,
          last_message_id: String.t() | nil,
          default_auto_archive_duration: integer() | nil,
          flags: integer() | nil,
          available_tags: [EDA.ForumTag.t()] | nil,
          applied_tags: [String.t()] | nil,
          default_reaction_emoji: map() | nil,
          default_thread_rate_limit_per_user: integer() | nil,
          default_sort_order: integer() | nil,
          default_forum_layout: integer() | nil,
          thread_metadata: map() | nil,
          owner_id: String.t() | nil,
          member_count: integer() | nil,
          message_count: integer() | nil,
          total_message_sent: integer() | nil,
          status: String.t() | nil
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

  # ── Type helpers ──

  @doc """
  Returns `true` if the channel is a forum channel (type 15).

  ## Examples

      iex> EDA.Channel.forum?(%EDA.Channel{type: 15})
      true

      iex> EDA.Channel.forum?(%EDA.Channel{type: 0})
      false
  """
  @spec forum?(t()) :: boolean()
  def forum?(%__MODULE__{type: @type_guild_forum}), do: true
  def forum?(%__MODULE__{}), do: false

  @doc """
  Returns `true` if the channel is a media channel (type 16).

  ## Examples

      iex> EDA.Channel.media?(%EDA.Channel{type: 16})
      true

      iex> EDA.Channel.media?(%EDA.Channel{type: 0})
      false
  """
  @spec media?(t()) :: boolean()
  def media?(%__MODULE__{type: @type_guild_media}), do: true
  def media?(%__MODULE__{}), do: false

  @doc """
  Returns `true` if the channel is a thread (types 10, 11, 12).

  ## Examples

      iex> EDA.Channel.thread?(%EDA.Channel{type: 11})
      true

      iex> EDA.Channel.thread?(%EDA.Channel{type: 0})
      false
  """
  @spec thread?(t()) :: boolean()
  def thread?(%__MODULE__{type: type})
      when type in [
             @type_guild_news_thread,
             @type_guild_public_thread,
             @type_guild_private_thread
           ],
      do: true

  def thread?(%__MODULE__{}), do: false

  # ── Parsing ──

  @spec from_raw(map()) :: t()
  def from_raw(raw) when is_map(raw) do
    %__MODULE__{
      id: raw["id"],
      type: raw["type"],
      guild_id: raw["guild_id"],
      position: raw["position"],
      permission_overwrites: parse_overwrites(raw["permission_overwrites"]),
      name: raw["name"],
      topic: raw["topic"],
      nsfw: raw["nsfw"],
      bitrate: raw["bitrate"],
      user_limit: raw["user_limit"],
      rate_limit_per_user: raw["rate_limit_per_user"],
      parent_id: raw["parent_id"],
      last_message_id: raw["last_message_id"],
      default_auto_archive_duration: raw["default_auto_archive_duration"],
      flags: raw["flags"],
      available_tags: parse_tags(raw["available_tags"]),
      applied_tags: raw["applied_tags"],
      default_reaction_emoji: raw["default_reaction_emoji"],
      default_thread_rate_limit_per_user: raw["default_thread_rate_limit_per_user"],
      default_sort_order: raw["default_sort_order"],
      default_forum_layout: raw["default_forum_layout"],
      thread_metadata: raw["thread_metadata"],
      owner_id: raw["owner_id"],
      member_count: raw["member_count"],
      message_count: raw["message_count"],
      total_message_sent: raw["total_message_sent"],
      status: raw["status"]
    }
  end

  defp parse_overwrites(nil), do: nil

  defp parse_overwrites(list) when is_list(list),
    do: Enum.map(list, &EDA.PermissionOverwrite.from_raw/1)

  defp parse_tags(nil), do: nil
  defp parse_tags(list) when is_list(list), do: Enum.map(list, &EDA.ForumTag.from_raw/1)

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
      raw -> {:ok, from_raw(raw)}
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
end
