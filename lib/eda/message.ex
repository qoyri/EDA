defmodule EDA.Message do
  @moduledoc "Represents a Discord message."
  use EDA.Event.Access

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
    :poll
  ]

  @type t :: %__MODULE__{
          id: String.t() | nil,
          channel_id: String.t() | nil,
          guild_id: String.t() | nil,
          author: EDA.User.t() | nil,
          content: String.t() | nil,
          timestamp: String.t() | nil,
          edited_timestamp: String.t() | nil,
          tts: boolean() | nil,
          mention_everyone: boolean() | nil,
          mentions: [EDA.User.t()] | nil,
          mention_roles: [String.t()] | nil,
          attachments: [EDA.Attachment.t()] | nil,
          embeds: [map()] | nil,
          reactions: [EDA.Reaction.t()] | nil,
          pinned: boolean() | nil,
          type: integer() | nil,
          member: EDA.Member.t() | nil,
          referenced_message: t() | nil,
          message_reference: map() | nil,
          components: [map()] | nil,
          sticker_items: [map()] | nil,
          poll: EDA.Poll.t() | nil
        }

  @spec from_raw(map()) :: t()
  def from_raw(raw) when is_map(raw) do
    %__MODULE__{
      id: raw["id"],
      channel_id: raw["channel_id"],
      guild_id: raw["guild_id"],
      author: parse_user(raw["author"]),
      content: raw["content"],
      timestamp: raw["timestamp"],
      edited_timestamp: raw["edited_timestamp"],
      tts: raw["tts"],
      mention_everyone: raw["mention_everyone"],
      mentions: parse_users(raw["mentions"]),
      mention_roles: raw["mention_roles"],
      attachments: parse_attachments(raw["attachments"]),
      embeds: raw["embeds"],
      reactions: parse_reactions(raw["reactions"]),
      pinned: raw["pinned"],
      type: raw["type"],
      member: parse_member(raw["member"]),
      referenced_message: parse_message(raw["referenced_message"]),
      message_reference: raw["message_reference"],
      components: raw["components"],
      sticker_items: raw["sticker_items"],
      poll: parse_poll(raw["poll"])
    }
  end

  defp parse_user(nil), do: nil
  defp parse_user(raw) when is_map(raw), do: EDA.User.from_raw(raw)

  defp parse_users(nil), do: nil
  defp parse_users(list) when is_list(list), do: Enum.map(list, &EDA.User.from_raw/1)

  defp parse_member(nil), do: nil
  defp parse_member(raw) when is_map(raw), do: EDA.Member.from_raw(raw)

  defp parse_attachments(nil), do: nil
  defp parse_attachments(list) when is_list(list), do: Enum.map(list, &EDA.Attachment.from_raw/1)

  defp parse_reactions(nil), do: nil
  defp parse_reactions(list) when is_list(list), do: Enum.map(list, &EDA.Reaction.from_raw/1)

  defp parse_message(nil), do: nil
  defp parse_message(raw) when is_map(raw), do: from_raw(raw)

  defp parse_poll(nil), do: nil
  defp parse_poll(raw) when is_map(raw), do: EDA.Poll.from_raw(raw)

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
