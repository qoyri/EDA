defmodule EDA.Channel.Thread do
  @moduledoc """
  What only a thread has, held in `EDA.Channel`'s `thread` field — `nil` on any other channel.

  Discord nests part of this under `thread_metadata`; it is flattened here, so a thread's state
  reads as `channel.thread.archived` or `channel.thread.locked`.

  - `member` — the bot's own membership (`EDA.Channel.ThreadMember`), `nil` when it has not
    joined. Discord sends it only on some routes and events
  - `newly_created` — `true` on the `THREAD_CREATE` of a thread that was just made, as opposed to
    the bot being added to an existing one
  - `message_count` and `member_count` stop counting at 50; `total_message_sent` never decreases,
    even when messages are deleted
  - `applied_tags` — the forum tags set on a forum or media post
  """

  use EDA.Event.Access

  defstruct [
    :archived,
    :auto_archive_duration,
    :archive_timestamp,
    :locked,
    :invitable,
    :create_timestamp,
    :member,
    :newly_created,
    :message_count,
    :member_count,
    :total_message_sent,
    :applied_tags
  ]

  @type t :: %__MODULE__{
          archived: boolean() | nil,
          auto_archive_duration: pos_integer() | nil,
          archive_timestamp: DateTime.t() | nil,
          locked: boolean() | nil,
          invitable: boolean() | nil,
          create_timestamp: DateTime.t() | nil,
          member: EDA.Channel.ThreadMember.t() | nil,
          newly_created: boolean() | nil,
          message_count: non_neg_integer() | nil,
          member_count: non_neg_integer() | nil,
          total_message_sent: non_neg_integer() | nil,
          applied_tags: [String.t()] | nil
        }

  @doc false
  # The keys of a raw channel that belong here, to recognise a thread whose type is missing.
  def raw_keys,
    do: ~w(thread_metadata member newly_created message_count member_count total_message_sent
           applied_tags)

  @doc "Takes the thread fields out of a raw channel object."
  @spec from_raw(map()) :: t()
  def from_raw(%__MODULE__{} = parsed), do: parsed

  def from_raw(raw) when is_map(raw) do
    metadata = :maps.get("thread_metadata", raw, nil) || %{}

    %__MODULE__{
      archived: metadata["archived"],
      auto_archive_duration: metadata["auto_archive_duration"],
      archive_timestamp: EDA.Timestamp.parse(metadata["archive_timestamp"]),
      locked: metadata["locked"],
      invitable: metadata["invitable"],
      create_timestamp: EDA.Timestamp.parse(metadata["create_timestamp"]),
      member: EDA.Channel.ThreadMember.from_raw(:maps.get("member", raw, nil)),
      newly_created: :maps.get("newly_created", raw, nil),
      message_count: :maps.get("message_count", raw, nil),
      member_count: :maps.get("member_count", raw, nil),
      total_message_sent: :maps.get("total_message_sent", raw, nil),
      applied_tags: :maps.get("applied_tags", raw, nil)
    }
  end
end
