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
  def from_raw(raw) when is_map(raw) do
    %__MODULE__{
      id: raw["id"],
      guild_id: raw["guild_id"],
      channel_id: raw["channel_id"],
      topic: raw["topic"],
      privacy_level: EDA.Enum.name(@privacy_levels, raw["privacy_level"]),
      discoverable_disabled: raw["discoverable_disabled"],
      guild_scheduled_event_id: raw["guild_scheduled_event_id"]
    }
  end

  @doc """
  The integer Discord uses for a privacy level, from its atom or the integer itself.

      iex> EDA.StageInstance.privacy_level_value(:guild_only)
      2
  """
  @spec privacy_level_value(atom() | integer()) :: integer()
  def privacy_level_value(level), do: EDA.Enum.value!(@privacy_levels, level, "privacy level")
end
