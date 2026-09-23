defmodule EDA.ScheduledEvent do
  @moduledoc """
  A guild scheduled event.

  Delivered by `GUILD_SCHEDULED_EVENT_CREATE`, `_UPDATE` and `_DELETE`; `EDA.API.ScheduledEvent`
  manages them over REST.

  - `entity_type` — `:stage_instance`, `:voice`, or `:external` for a place outside Discord,
    whose location is in `entity_metadata.location` (an `EDA.ScheduledEvent.EntityMetadata`)
  - `status` — `:scheduled`, `:active`, `:completed` or `:canceled`
  - `image` — the cover image hash
  - `recurrence_rule` — how often it repeats, an `EDA.ScheduledEvent.RecurrenceRule`, `nil` for
    a one-off
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
          entity_metadata: EDA.ScheduledEvent.EntityMetadata.t() | nil,
          creator: EDA.User.t() | nil,
          user_count: non_neg_integer() | nil,
          image: String.t() | nil,
          recurrence_rule: EDA.ScheduledEvent.RecurrenceRule.t() | nil
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
      entity_metadata: EDA.ScheduledEvent.EntityMetadata.from_raw(raw["entity_metadata"]),
      creator: parse_user(raw["creator"]),
      user_count: raw["user_count"],
      image: raw["image"],
      recurrence_rule: EDA.ScheduledEvent.RecurrenceRule.from_raw(raw["recurrence_rule"])
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

  # ── Entity Manager ──

  use EDA.Entity

  @doc "Lists a guild's scheduled events. With `with_user_count: true`, each has `user_count`."
  @spec list(String.t() | integer(), keyword()) :: {:ok, [t()]} | {:error, term()}
  def list(guild_id, opts \\ []),
    do: EDA.API.ScheduledEvent.list(guild_id, opts) |> parse_list()

  @doc """
  Fetches one scheduled event. Takes `with_user_count: true`.

  Named `fetch_event/3` rather than `fetch/2` because `Access.fetch/2` owns that arity.
  """
  @spec fetch_event(String.t() | integer(), String.t() | integer(), keyword()) ::
          {:ok, t()} | {:error, term()}
  def fetch_event(guild_id, event_id, opts \\ []),
    do: EDA.API.ScheduledEvent.get(guild_id, event_id, opts) |> parse_response()

  @doc """
  Creates a scheduled event. Takes the parameters of `EDA.API.ScheduledEvent.create/2`, with
  atoms for the enumerations and an `EDA.ScheduledEvent.RecurrenceRule` if it repeats.
  """
  @spec create(String.t() | integer(), map()) :: {:ok, t()} | {:error, term()}
  def create(guild_id, params),
    do: EDA.API.ScheduledEvent.create(guild_id, params) |> parse_response()

  @doc "Modifies a scheduled event, or starts, ends or cancels it through `status`."
  @spec modify(String.t() | integer(), t() | String.t() | integer(), map()) ::
          {:ok, t()} | {:error, term()}
  def modify(guild_id, %__MODULE__{id: id}, params), do: modify(guild_id, id, params)

  def modify(guild_id, event_id, params),
    do: EDA.API.ScheduledEvent.modify(guild_id, event_id, params) |> parse_response()

  @doc "Deletes a scheduled event."
  @spec delete(String.t() | integer(), t() | String.t() | integer()) :: :ok | {:error, term()}
  def delete(guild_id, %__MODULE__{id: id}), do: delete(guild_id, id)
  def delete(guild_id, event_id), do: EDA.API.ScheduledEvent.delete(guild_id, event_id)

  @doc """
  One page of the users interested in the event, as `EDA.ScheduledEvent.Subscriber` structs.
  Takes `:limit`, `:before`, `:after` and `with_member: true`.
  """
  @spec subscribers(t(), keyword()) ::
          {:ok, [EDA.ScheduledEvent.Subscriber.t()]} | {:error, term()}
  def subscribers(%__MODULE__{guild_id: guild_id, id: id}, opts \\ []) do
    case EDA.API.ScheduledEvent.users(guild_id, id, opts) do
      {:ok, list} when is_list(list) ->
        {:ok, Enum.map(list, &EDA.ScheduledEvent.Subscriber.from_raw/1)}

      {:error, _} = err ->
        err
    end
  end

  @doc """
  A lazy stream of every user interested in the event. Takes the options of `subscribers/2`
  and `:per_page`.
  """
  @spec stream_subscribers(t(), keyword()) :: Enumerable.t()
  def stream_subscribers(%__MODULE__{guild_id: guild_id, id: id}, opts \\ []) do
    guild_id
    |> EDA.API.ScheduledEvent.user_stream(id, opts)
    |> Stream.map(&EDA.ScheduledEvent.Subscriber.from_raw/1)
  end

  defp parse_list({:ok, list}) when is_list(list), do: {:ok, Enum.map(list, &from_raw/1)}
  defp parse_list({:error, _} = err), do: err
end
