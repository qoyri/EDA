defmodule EDA.Channel.Voice do
  @moduledoc """
  What only a voice or stage channel has, held in `EDA.Channel`'s `voice` field — `nil` on any
  other channel.

  - `bitrate` — in bits per second; the ceiling depends on the guild's boost level
  - `user_limit` — 0 means no limit
  - `rtc_region` — the voice region id, `nil` for automatic
  - `video_quality_mode` — 1 for automatic, 2 for 720p
  - `status` — the voice channel status text, set with `EDA.Channel.set_voice_status/3`
  """

  use EDA.Event.Access

  defstruct [:bitrate, :user_limit, :rtc_region, :video_quality_mode, :status]

  @type t :: %__MODULE__{
          bitrate: pos_integer() | nil,
          user_limit: non_neg_integer() | nil,
          rtc_region: String.t() | nil,
          video_quality_mode: pos_integer() | nil,
          status: String.t() | nil
        }

  @doc false
  def raw_keys, do: ~w(bitrate user_limit rtc_region video_quality_mode status)

  @doc "Takes the voice fields out of a raw channel object."
  @spec from_raw(map()) :: t()
  def from_raw(raw) when is_map(raw) do
    %__MODULE__{
      bitrate: raw["bitrate"],
      user_limit: raw["user_limit"],
      rtc_region: raw["rtc_region"],
      video_quality_mode: raw["video_quality_mode"],
      status: raw["status"]
    }
  end
end
