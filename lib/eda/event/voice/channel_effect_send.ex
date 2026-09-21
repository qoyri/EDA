defmodule EDA.Event.VoiceChannelEffectSend do
  @moduledoc """
  Dispatched when someone sends an effect — an emoji reaction or a soundboard sound — in a
  voice channel the bot is connected to. Needs the `:guild_voice_states` intent.

  For a soundboard sound, `sound_id` and `sound_volume` are set; for an emoji reaction they
  are `nil`. `animation_type` is `:premium` for the animation a Nitro subscriber sends and
  `:basic` for the standard one.
  """
  use EDA.Event.Access

  defstruct [
    :channel_id,
    :guild_id,
    :user_id,
    :emoji,
    :animation_type,
    :animation_id,
    :sound_id,
    :sound_volume
  ]

  @type t :: %__MODULE__{
          channel_id: String.t() | nil,
          guild_id: String.t() | nil,
          user_id: String.t() | nil,
          emoji: EDA.Emoji.t() | nil,
          animation_type: :premium | :basic | integer() | nil,
          animation_id: integer() | nil,
          sound_id: String.t() | nil,
          sound_volume: float() | nil
        }

  @animation_types %{0 => :premium, 1 => :basic}

  @doc "Converts a raw Discord payload into this event struct."
  @spec from_raw(map()) :: t()
  def from_raw(raw) when is_map(raw) do
    %__MODULE__{
      channel_id: raw["channel_id"],
      guild_id: raw["guild_id"],
      user_id: raw["user_id"],
      emoji: if(is_map(raw["emoji"]), do: EDA.Emoji.from_raw(raw["emoji"])),
      animation_type: Map.get(@animation_types, raw["animation_type"], raw["animation_type"]),
      animation_id: raw["animation_id"],
      # A default sound's id is sent as an integer.
      sound_id: if(raw["sound_id"], do: to_string(raw["sound_id"])),
      sound_volume: raw["sound_volume"]
    }
  end

  @doc "Whether this effect is a soundboard sound rather than an emoji reaction."
  @spec soundboard?(t()) :: boolean()
  def soundboard?(%__MODULE__{sound_id: id}), do: not is_nil(id)
end
