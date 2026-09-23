defmodule EDA.ScheduledEvent do
  @moduledoc """
  A guild scheduled event.

  Delivered by `GUILD_SCHEDULED_EVENT_CREATE`, `_UPDATE` and `_DELETE`; `EDA.API.ScheduledEvent`
  manages them over REST.

  - `entity_type` — 1 for a stage instance, 2 for a voice channel, 3 for an external place, whose
    location is in `entity_metadata["location"]`
  - `status` — 1 scheduled, 2 active, 3 completed, 4 canceled
  - `image` — the cover image hash
  - `recurrence_rule` — how often it repeats, as the map Discord sent, `nil` for a one-off
  - `creator` — an `EDA.User`, absent for events created before October 2021
  """

  use EDA.Event.Access

  @entity_types %{1 => :stage_instance, 2 => :voice, 3 => :external}

  @statuses %{1 => :scheduled, 2 => :active, 3 => :completed, 4 => :canceled}

  @privacy_levels %{2 => :guild_only}

  defstruct [
    :id,
    :guild_id,
    :channel_id,
    :creator_id,
    :name,
    :description,
    :scheduled_start_time,
    :scheduled_end_time,
    :privacy_level,
    :status,
    :entity_type,
    :entity_id,
    :entity_metadata,
    :creator,
    :user_count,
    :image,
    :recurrence_rule
  ]

  @type t :: %__MODULE__{
          id: String.t() | nil,
          guild_id: String.t() | nil,
          channel_id: String.t() | nil,
          creator_id: String.t() | nil,
          name: String.t() | nil,
          description: String.t() | nil,
          scheduled_start_time: DateTime.t() | nil,
          scheduled_end_time: DateTime.t() | nil,
          privacy_level: :guild_only | integer() | nil,
          status: :scheduled | :active | :completed | :canceled | integer() | nil,
          entity_type: :stage_instance | :voice | :external | integer() | nil,
          entity_id: String.t() | nil,
          entity_metadata: map() | nil,
          creator: EDA.User.t() | nil,
          user_count: non_neg_integer() | nil,
          image: String.t() | nil,
          recurrence_rule: map() | nil
        }

  @doc "Parses a raw scheduled event object."
  @spec from_raw(map()) :: t()
  def from_raw(raw) when is_map(raw) do
    %__MODULE__{
      id: raw["id"],
      guild_id: raw["guild_id"],
      channel_id: raw["channel_id"],
      creator_id: raw["creator_id"],
      name: raw["name"],
      description: raw["description"],
      scheduled_start_time: EDA.Timestamp.parse(raw["scheduled_start_time"]),
      scheduled_end_time: EDA.Timestamp.parse(raw["scheduled_end_time"]),
      privacy_level: EDA.Enum.name(@privacy_levels, raw["privacy_level"]),
      status: EDA.Enum.name(@statuses, raw["status"]),
      entity_type: EDA.Enum.name(@entity_types, raw["entity_type"]),
      entity_id: raw["entity_id"],
      entity_metadata: raw["entity_metadata"],
      creator: parse_user(raw["creator"]),
      user_count: raw["user_count"],
      image: raw["image"],
      recurrence_rule: raw["recurrence_rule"]
    }
  end

  defp parse_user(nil), do: nil
  defp parse_user(raw) when is_map(raw), do: EDA.User.from_raw(raw)

  @doc """
  The integer Discord uses for a privacy level, from its atom or the integer itself.
  """
  @spec privacy_level_value(atom() | integer()) :: integer()
  def privacy_level_value(value), do: EDA.Enum.value!(@privacy_levels, value, "privacy level")

  @doc """
  The integer Discord uses for a scheduled event status, from its atom or the integer itself.
  """
  @spec status_value(atom() | integer()) :: integer()
  def status_value(value), do: EDA.Enum.value!(@statuses, value, "scheduled event status")

  @doc """
  The integer Discord uses for a scheduled event entity type, from its atom or the integer itself.
  """
  @spec entity_type_value(atom() | integer()) :: integer()
  def entity_type_value(value),
    do: EDA.Enum.value!(@entity_types, value, "scheduled event entity type")
end
