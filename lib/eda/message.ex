defmodule EDA.Message do
  @moduledoc """
  A Discord message, from the REST API or from `MESSAGE_CREATE` and `MESSAGE_UPDATE`.

  The two gateway events deliver this struct itself, so what a bot receives can be passed
  straight to `reply/2`, `edit/2`, `react/2` or `delete/2`. They add `guild_id`, `member` and
  `channel_type`, which a message fetched over REST does not carry.

  Every field Discord documents is kept, each nested object as its struct: embeds are
  `EDA.Embed`, components `EDA.Component` structs, `message_reference` an
  `EDA.Message.Reference`, `sticker_items` `EDA.Sticker.Item`s, `interaction_metadata`,
  `call`, `activity`, `role_subscription_data`, `shared_client_theme` and `mention_channels`
  their `EDA.Message.*` structs, `application` an `EDA.App` and `resolved` an `EDA.Resolved`.

  A forwarded message has `message_reference.type == :forward` and the message it forwards in
  `message_snapshots`, as a partial `EDA.Message`: Discord wraps each in a `message` key, which
  EDA leaves out.

  Without the `MESSAGE_CONTENT` intent, `content`, `embeds`, `attachments` and `components`
  arrive empty and `poll` is absent, for messages the bot is neither mentioned in nor the
  author of.
  """
  use EDA.Event.Access

  @types %{
    0 => :default,
    1 => :recipient_add,
    2 => :recipient_remove,
    3 => :call,
    4 => :channel_name_change,
    5 => :channel_icon_change,
    6 => :channel_pinned_message,
    7 => :user_join,
    8 => :guild_boost,
    9 => :guild_boost_tier_1,
    10 => :guild_boost_tier_2,
    11 => :guild_boost_tier_3,
    12 => :channel_follow_add,
    14 => :guild_discovery_disqualified,
    15 => :guild_discovery_requalified,
    16 => :guild_discovery_grace_period_initial_warning,
    17 => :guild_discovery_grace_period_final_warning,
    18 => :thread_created,
    19 => :reply,
    20 => :chat_input_command,
    21 => :thread_starter_message,
    22 => :guild_invite_reminder,
    23 => :context_menu_command,
    24 => :auto_moderation_action,
    25 => :role_subscription_purchase,
    26 => :interaction_premium_upsell,
    27 => :stage_start,
    28 => :stage_end,
    29 => :stage_speaker,
    31 => :stage_topic,
    32 => :guild_application_premium_subscription,
    36 => :guild_incident_alert_mode_enabled,
    37 => :guild_incident_alert_mode_disabled,
    38 => :guild_incident_report_raid,
    39 => :guild_incident_report_false_alarm,
    44 => :purchase_notification,
    46 => :poll_result
  }

  # A message is not cached, so a map past its compact form costs nothing held in bulk; its
  # fields stay flat, as Discord sends them. The limit matters for what the cache holds by the
  # thousand; see test/eda/cached_struct_size_test.exs.
  # credo:disable-for-next-line Credo.Check.Warning.StructFieldAmount
  defstruct [
    :id,
    :channel_id,
    :guild_id,
    :author,
    :content,
    :timestamp,
    :edited_timestamp,
    :tts,
    :mention_everyone,
    :mentions,
    :mention_roles,
    :attachments,
    :embeds,
    :reactions,
    :pinned,
    :type,
    :member,
    :referenced_message,
    :message_reference,
    :components,
    :sticker_items,
    :poll,
    :webhook_id,
    :application_id,
    :flags,
    :interaction_metadata,
    :message_snapshots,
    :thread,
    :mention_channels,
    :nonce,
    :position,
    :activity,
    :application,
    :call,
    :role_subscription_data,
    :resolved,
    :shared_client_theme,
    :channel_type
  ]

  @type t :: %__MODULE__{
          id: String.t() | nil,
          channel_id: String.t() | nil,
          guild_id: String.t() | nil,
          author: EDA.User.t() | nil,
          content: String.t() | nil,
          timestamp: DateTime.t() | nil,
          edited_timestamp: DateTime.t() | nil,
          tts: boolean() | nil,
          mention_everyone: boolean() | nil,
          mentions: [EDA.User.t()] | nil,
          mention_roles: [String.t()] | nil,
          attachments: [EDA.Attachment.t()] | nil,
          embeds: [EDA.Embed.t()] | nil,
          reactions: [EDA.Reaction.t()] | nil,
          pinned: boolean() | nil,
          type: atom() | integer() | nil,
          member: EDA.Member.t() | nil,
          referenced_message: t() | nil,
          message_reference: EDA.Message.Reference.t() | nil,
          components: [EDA.Component.t()] | nil,
          sticker_items: [EDA.Sticker.Item.t()] | nil,
          poll: EDA.Poll.t() | nil,
          webhook_id: String.t() | nil,
          application_id: String.t() | nil,
          flags: non_neg_integer() | nil,
          interaction_metadata: EDA.Message.InteractionMetadata.t() | nil,
          message_snapshots: [t()] | nil,
          thread: EDA.Channel.t() | nil,
          mention_channels: [EDA.Message.ChannelMention.t()] | nil,
          nonce: String.t() | integer() | nil,
          position: integer() | nil,
          activity: EDA.Message.Activity.t() | nil,
          application: EDA.App.t() | nil,
          call: EDA.Message.Call.t() | nil,
          role_subscription_data: EDA.Message.RoleSubscriptionData.t() | nil,
          resolved: EDA.Resolved.t() | nil,
          shared_client_theme: EDA.Message.SharedClientTheme.t() | nil,
          channel_type: EDA.Channel.channel_type() | nil
        }

  @spec from_raw(map()) :: t()
  def from_raw(raw) when is_map(raw) do
    %__MODULE__{
      id: raw["id"],
      channel_id: raw["channel_id"],
      guild_id: raw["guild_id"],
      author: parse_user(raw["author"]),
      content: raw["content"],
      timestamp: EDA.Timestamp.parse(raw["timestamp"]),
      edited_timestamp: EDA.Timestamp.parse(raw["edited_timestamp"]),
      tts: raw["tts"],
      mention_everyone: raw["mention_everyone"],
      mentions: parse_mentions(raw["mentions"], raw["guild_id"]),
      mention_roles: raw["mention_roles"],
      attachments: parse_attachments(raw["attachments"]),
      embeds: parse_list(raw["embeds"], &EDA.Embed.from_raw/1),
      reactions: parse_reactions(raw["reactions"]),
      pinned: raw["pinned"],
      type: EDA.Enum.name(@types, raw["type"]),
      member: parse_member(raw["member"]),
      referenced_message: parse_message(raw["referenced_message"]),
      message_reference: EDA.Message.Reference.from_raw(raw["message_reference"]),
      components: parse_list(raw["components"], &EDA.Component.from_raw/1),
      sticker_items: parse_list(raw["sticker_items"], &EDA.Sticker.Item.from_raw/1),
      poll: parse_poll(raw["poll"]),
      webhook_id: raw["webhook_id"],
      application_id: raw["application_id"],
      flags: raw["flags"],
      interaction_metadata: EDA.Message.InteractionMetadata.from_raw(raw["interaction_metadata"]),
      message_snapshots: parse_list(raw["message_snapshots"], &parse_snapshot/1),
      thread: parse_thread(raw["thread"]),
      mention_channels:
        parse_list(raw["mention_channels"], &EDA.Message.ChannelMention.from_raw/1),
      nonce: raw["nonce"],
      position: raw["position"],
      activity: EDA.Message.Activity.from_raw(raw["activity"]),
      application: parse_application(raw["application"]),
      call: EDA.Message.Call.from_raw(raw["call"]),
      role_subscription_data:
        EDA.Message.RoleSubscriptionData.from_raw(raw["role_subscription_data"]),
      resolved: EDA.Resolved.from_raw(raw["resolved"]),
      shared_client_theme: EDA.Message.SharedClientTheme.from_raw(raw["shared_client_theme"]),
      channel_type: EDA.Channel.type_name(raw["channel_type"])
    }
  end

  # A forwarded message's snapshot wraps the partial message in `message`; the list holds the
  # messages themselves.
  defp parse_snapshot(%{"message" => message}), do: from_raw(message)
  defp parse_snapshot(raw), do: from_raw(raw)

  defp parse_application(nil), do: nil
  defp parse_application(raw), do: EDA.App.from_raw(raw)

  defp parse_list(nil, _parse), do: nil
  defp parse_list(list, parse) when is_list(list), do: Enum.map(list, parse)

  defp parse_user(nil), do: nil
  defp parse_user(raw) when is_map(raw), do: EDA.User.from_raw(raw)

  # In a guild, each mentioned user carries their partial member, which gets the guild's id.
  defp parse_mentions(nil, _guild_id), do: nil

  defp parse_mentions(list, guild_id) when is_list(list) do
    Enum.map(list, fn raw ->
      case EDA.User.from_raw(raw) do
        %EDA.User{member: %EDA.Member{} = member} = user ->
          %{user | member: %{member | guild_id: guild_id}}

        user ->
          user
      end
    end)
  end

  defp parse_member(nil), do: nil
  defp parse_member(raw) when is_map(raw), do: EDA.Member.from_raw(raw)

  defp parse_attachments(nil), do: nil
  defp parse_attachments(list) when is_list(list), do: Enum.map(list, &EDA.Attachment.from_raw/1)

  defp parse_reactions(nil), do: nil
  defp parse_reactions(list) when is_list(list), do: Enum.map(list, &EDA.Reaction.from_raw/1)

  defp parse_message(nil), do: nil
  defp parse_message(raw) when is_map(raw), do: from_raw(raw)

  defp parse_thread(nil), do: nil
  defp parse_thread(raw) when is_map(raw), do: EDA.Channel.from_raw(raw)

  defp parse_poll(nil), do: nil
  defp parse_poll(raw) when is_map(raw), do: EDA.Poll.from_raw(raw)

  @doc """
  What the message is — ephemeral, a voice message, a forward… — from `flags`, as
  `EDA.Message.Flags` names them. Accepts a struct or a raw map, and gives `[]` when Discord sent
  none.

      iex> EDA.Message.flags(%EDA.Message{flags: 8256})
      [:ephemeral, :is_voice_message]
  """
  @spec flags(t() | map()) :: [EDA.Message.Flags.flag()]
  def flags(%__MODULE__{flags: flags}), do: EDA.Message.Flags.to_list(flags)
  def flags(%{"flags" => flags}), do: EDA.Message.Flags.to_list(flags)
  def flags(_), do: []

  @doc """
  Whether `flags` carries a flag.

      iex> EDA.Message.flag?(%EDA.Message{flags: 8256}, :ephemeral)
      true
  """
  @spec flag?(t() | map(), EDA.Message.Flags.flag()) :: boolean()
  def flag?(%__MODULE__{flags: flags}, flag), do: EDA.Message.Flags.has?(flags, flag)
  def flag?(%{"flags" => flags}, flag), do: EDA.Message.Flags.has?(flags, flag)
  def flag?(_, _flag), do: false

  # ── Entity Manager ──

  use EDA.Entity

  @doc """
  Fetches a message by channel ID and message ID. No cache (messages are not cached).
  """
  @spec fetch_message(String.t() | integer(), String.t() | integer()) ::
          {:ok, t()} | {:error, term()}
  def fetch_message(channel_id, message_id) do
    EDA.API.Message.get(channel_id, message_id) |> parse_response()
  end

  @doc """
  Edits a message. Accepts a raw payload map or a keyword list of options.

  The keyword form supports everything `EDA.API.Message.edit/3` does, including `:files`
  and `:attachments`.

  ## Attachments are replaced, not merged

  Discord deletes any attachment missing from the `attachments` array, so uploading a file
  to a message that already has some wipes them unless they are named. Since the struct
  already carries them, `attachments: :keep` says "everything this message has now", with
  no extra request:

      EDA.Message.edit(message,
        content: "one more",
        attachments: :keep,
        files: [EDA.File.from_path("extra.png")]
      )

  Pass a list instead to keep only part of them, or to change what an attachment says —
  see `EDA.Attachment.keep/2`:

      EDA.Message.edit(message,
        attachments: [EDA.Attachment.keep(hd(message.attachments), is_spoiler: true)]
      )
  """
  @spec edit(t(), map() | keyword()) :: {:ok, t()} | {:error, term()}
  def edit(message, payload)

  def edit(%__MODULE__{channel_id: cid, id: mid}, payload) when is_map(payload) do
    EDA.API.Message.edit(cid, mid, payload) |> parse_response()
  end

  def edit(%__MODULE__{channel_id: cid, id: mid} = message, opts) when is_list(opts) do
    EDA.API.Message.edit(cid, mid, resolve_keep(opts, message)) |> parse_response()
  end

  # `attachments: :keep` is shorthand for the attachments the struct already holds. An empty
  # array would delete them all, so a message with none drops the key entirely.
  defp resolve_keep(opts, %__MODULE__{attachments: attachments}) do
    case Keyword.fetch(opts, :attachments) do
      {:ok, :keep} when attachments in [nil, []] ->
        Keyword.delete(opts, :attachments)

      {:ok, :keep} ->
        Keyword.put(opts, :attachments, Enum.map(attachments, &EDA.Attachment.keep/1))

      _ ->
        opts
    end
  end

  @doc """
  Searches a guild's message history, returning structs.

  Takes the same options as `EDA.API.Message.search/2`, and flattens the nesting that
  endpoint returns:

      {:ok, found} = EDA.Message.search(guild_id, content: "deploy", has: [:link])

      found.total_results   #=> 1034 (approximate, see below)
      found.results         #=> [%EDA.Message{}, ...] — the matches themselves
      found.groups          #=> [[%EDA.Message{}], ...] — each match with its neighbours
      found.indexing?       #=> false

  `:results` is what you almost always want. `:groups` keeps the surrounding messages
  Discord sends for context; a group is usually one message, but that is not promised, and
  the match inside it is the one `:results` picked.

  `:total_results` is Discord's own count and is approximate while messages are being
  created or deleted. `:indexing?` is true while Discord is still walking the guild's older
  history, which means more results may appear later for the same query.

  Requires `READ_MESSAGE_HISTORY` and the `MESSAGE_CONTENT` intent. A guild that is not
  indexed yet answers `{:error, {:index_pending, retry_after_seconds}}`.
  """
  @spec search(String.t() | integer(), keyword()) ::
          {:ok,
           %{results: [t()], groups: [[t()]], total_results: integer(), indexing?: boolean()}}
          | {:error, term()}
  def search(guild_id, opts \\ []) do
    case EDA.API.Message.search(guild_id, opts) do
      {:ok, body} when is_map(body) -> {:ok, parse_search(body)}
      {:error, _} = err -> err
    end
  end

  defp parse_search(body) do
    raw_groups =
      body
      |> Map.get("messages", [])
      |> Enum.map(&as_group/1)

    %{
      results: Enum.map(raw_groups, &(&1 |> pick_hit() |> from_raw())),
      groups: Enum.map(raw_groups, fn group -> Enum.map(group, &from_raw/1) end),
      total_results: body["total_results"] || 0,
      indexing?: body["doing_deep_historical_index"] == true
    }
  end

  # Discord nests each result in a context group; a bare map would still parse.
  defp as_group(group) when is_list(group), do: group
  defp as_group(raw) when is_map(raw), do: [raw]

  # `hit` marks the match inside its group. It is not a field of a message object, so
  # `from_raw/1` drops it — the choice has to be made on the raw map, before parsing.
  defp pick_hit([single]), do: single
  defp pick_hit(group), do: Enum.find(group, &(&1["hit"] == true)) || List.first(group)

  @doc """
  Deletes a message.

  ## Options

  - `:reason` - Audit log reason
  """
  @spec delete(t(), keyword()) :: :ok | {:error, term()}
  def delete(message, opts \\ [])

  def delete(%__MODULE__{channel_id: cid, id: mid}, opts) do
    EDA.API.Message.delete(cid, mid, opts)
  end

  @doc """
  Pins a message in its channel.

  ## Options

  - `:reason` - Audit log reason
  """
  @spec pin(t(), keyword()) :: :ok | {:error, term()}
  def pin(%__MODULE__{channel_id: cid, id: mid}, opts \\ []) do
    EDA.API.Message.pin(cid, mid, opts)
  end

  @doc """
  Publishes a message from an announcement channel to every channel following it, and returns it
  updated. See `EDA.API.Message.crosspost/2` for the permissions.
  """
  @spec crosspost(t()) :: {:ok, t()} | {:error, term()}
  def crosspost(%__MODULE__{channel_id: cid, id: mid}) do
    case EDA.API.Message.crosspost(cid, mid) do
      {:ok, raw} -> {:ok, from_raw(raw)}
      error -> error
    end
  end

  @doc """
  Unpins a message from its channel.

  ## Options

  - `:reason` - Audit log reason
  """
  @spec unpin(t(), keyword()) :: :ok | {:error, term()}
  def unpin(%__MODULE__{channel_id: cid, id: mid}, opts \\ []) do
    EDA.API.Message.unpin(cid, mid, opts)
  end

  @doc """
  Adds a reaction to a message.

  The `emoji` parameter accepts a string (`"👍"` or `"name:id"`) or an `EDA.Emoji` struct.
  """
  @spec react(t(), String.t() | EDA.Emoji.t()) :: :ok | {:error, term()}
  def react(%__MODULE__{channel_id: cid, id: mid}, emoji) do
    EDA.API.Reaction.create(cid, mid, emoji)
  end

  @doc """
  Replies to a message. Returns a `%EDA.Message{}` struct.
  """
  @spec reply(t(), String.t() | map() | keyword()) :: {:ok, t()} | {:error, term()}
  def reply(%__MODULE__{channel_id: cid, id: mid}, content) when is_binary(content) do
    payload = %{content: content, message_reference: %{message_id: mid}}

    case EDA.API.Message.create(cid, payload) do
      {:ok, raw} when is_map(raw) -> {:ok, from_raw(raw)}
      {:error, _} = err -> err
    end
  end

  def reply(%__MODULE__{channel_id: cid, id: mid}, payload) when is_map(payload) do
    payload = Map.put(payload, :message_reference, %{message_id: mid})

    case EDA.API.Message.create(cid, payload) do
      {:ok, raw} when is_map(raw) -> {:ok, from_raw(raw)}
      {:error, _} = err -> err
    end
  end

  @doc """
  Applies a changeset to a message. No-op if the changeset has no changes.
  """
  @spec apply_changeset(Changeset.t(), keyword()) :: {:ok, t()} | {:error, term()}
  def apply_changeset(changeset, opts \\ [])

  def apply_changeset(%Changeset{module: __MODULE__, entity: entity} = cs, _opts) do
    if Changeset.changed?(cs) do
      edit(entity, Changeset.changes(cs))
    else
      {:ok, entity}
    end
  end
end
