defmodule EDA.StageInstance do
  @moduledoc """
  A live stage: the topic being discussed in a stage channel.

  Delivered by `STAGE_INSTANCE_CREATE`, `_UPDATE` and `_DELETE`; `EDA.API.Stage` manages them over
  REST.

  - `privacy_level` — `:guild_only`, or `:public` on older stages (Discord deprecated it); a value
    EDA does not know stays the integer
  - `guild_scheduled_event_id` — the scheduled event that started it, if any
  - `discoverable_disabled` — deprecated by Discord, kept as sent
  """

  use EDA.Event.Access

  @privacy_levels %{1 => :public, 2 => :guild_only}

  defstruct [
    :id,
    :guild_id,
    :channel_id,
    :topic,
    :privacy_level,
    :discoverable_disabled,
    :guild_scheduled_event_id
  ]

  @type t :: %__MODULE__{
          id: String.t() | nil,
          guild_id: String.t() | nil,
          channel_id: String.t() | nil,
          topic: String.t() | nil,
          privacy_level: :public | :guild_only | integer() | nil,
          discoverable_disabled: boolean() | nil,
          guild_scheduled_event_id: String.t() | nil
        }

  @doc "Parses a raw stage instance object."
  @spec from_raw(map()) :: t()
  def from_raw(%__MODULE__{} = parsed), do: parsed

  def from_raw(raw) when is_map(raw) do
    %__MODULE__{
      id: :maps.get("id", raw, nil),
      guild_id: :maps.get("guild_id", raw, nil),
      channel_id: :maps.get("channel_id", raw, nil),
      topic: :maps.get("topic", raw, nil),
      privacy_level: EDA.Enum.name(@privacy_levels, :maps.get("privacy_level", raw, nil)),
      discoverable_disabled: :maps.get("discoverable_disabled", raw, nil),
      guild_scheduled_event_id: :maps.get("guild_scheduled_event_id", raw, nil)
    }
  end

  @doc """
  The integer Discord uses for a privacy level, from its atom or the integer itself.

      iex> EDA.StageInstance.privacy_level_value(:guild_only)
      2
  """
  @spec privacy_level_value(atom() | integer()) :: integer()
  def privacy_level_value(level), do: EDA.Enum.value!(@privacy_levels, level, "privacy level")

  # ── Entity Manager ──

  use EDA.Entity

  @doc """
  Opens a stage: takes `:channel_id`, `:topic` and optionally `:privacy_level`,
  `:send_start_notification` and `:guild_scheduled_event_id`.
  """
  @spec create(map()) :: {:ok, t()} | {:error, term()}
  def create(params), do: EDA.API.Stage.create(params) |> parse_response()

  @doc "Fetches the live stage in a stage channel."
  @spec fetch(String.t() | integer()) :: {:ok, t()} | {:error, term()}
  def fetch(channel_id), do: EDA.API.Stage.get(channel_id) |> parse_response()

  @doc "Changes a live stage's `topic` or `privacy_level`."
  @spec modify(t() | String.t() | integer(), map()) :: {:ok, t()} | {:error, term()}
  def modify(%__MODULE__{channel_id: channel_id}, params), do: modify(channel_id, params)
  def modify(channel_id, params), do: EDA.API.Stage.modify(channel_id, params) |> parse_response()

  @doc "Ends a stage."
  @spec delete(t() | String.t() | integer()) :: :ok | {:error, term()}
  def delete(%__MODULE__{channel_id: channel_id}), do: delete(channel_id)
  def delete(channel_id), do: EDA.API.Stage.delete(channel_id)
end
