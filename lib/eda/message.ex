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
  Edits a message. Accepts a struct or channel_id + message_id.
  """
  @spec edit(t(), map()) :: {:ok, t()} | {:error, term()}
  def edit(%__MODULE__{channel_id: cid, id: mid}, payload) when is_map(payload) do
    EDA.API.Message.edit(cid, mid, payload) |> parse_response()
  end

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
