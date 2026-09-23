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
  def from_raw(%__MODULE__{} = parsed), do: parsed

  def from_raw(raw) when is_map(raw) do
    %__MODULE__{
      channel_id: :maps.get("channel_id", raw, nil),
      guild_id: :maps.get("guild_id", raw, nil),
      user_id: :maps.get("user_id", raw, nil),
      emoji:
        if(is_map(:maps.get("emoji", raw, nil)),
          do: EDA.Emoji.from_raw(:maps.get("emoji", raw, nil))
        ),
      animation_type:
        Map.get(
          @animation_types,
          :maps.get("animation_type", raw, nil),
          :maps.get("animation_type", raw, nil)
        ),
      animation_id: :maps.get("animation_id", raw, nil),
      # A default sound's id is sent as an integer.
      sound_id:
        if(:maps.get("sound_id", raw, nil), do: to_string(:maps.get("sound_id", raw, nil))),
      sound_volume: :maps.get("sound_volume", raw, nil)
    }
  end

  @doc "Whether this effect is a soundboard sound rather than an emoji reaction."
  @spec soundboard?(t()) :: boolean()
  def soundboard?(%__MODULE__{sound_id: id}), do: not is_nil(id)
end
