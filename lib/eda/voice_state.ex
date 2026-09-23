defmodule EDA.VoiceState do
  @moduledoc "Represents a Discord voice state."
  use EDA.Event.Access

  defstruct [
    :guild_id,
    :channel_id,
    :user_id,
    :member,
    :session_id,
    :deaf,
    :mute,
    :self_deaf,
    :self_mute,
    :self_stream,
    :self_video,
    :suppress,
    :request_to_speak_timestamp
  ]

  @type t :: %__MODULE__{
          guild_id: String.t() | nil,
          channel_id: String.t() | nil,
          user_id: String.t() | nil,
          member: EDA.Member.t() | nil,
          session_id: String.t() | nil,
          deaf: boolean() | nil,
          mute: boolean() | nil,
          self_deaf: boolean() | nil,
          self_mute: boolean() | nil,
          self_stream: boolean() | nil,
          self_video: boolean() | nil,
          suppress: boolean() | nil,
          request_to_speak_timestamp: DateTime.t() | nil
        }

  @spec from_raw(map()) :: t()
  def from_raw(raw) when is_map(raw) do
    %__MODULE__{
      guild_id: raw["guild_id"],
      channel_id: raw["channel_id"],
      user_id: raw["user_id"],
      member: parse_member(raw["member"]),
      session_id: raw["session_id"],
      deaf: raw["deaf"],
      mute: raw["mute"],
      self_deaf: raw["self_deaf"],
      self_mute: raw["self_mute"],
      self_stream: raw["self_stream"],
      self_video: raw["self_video"],
      suppress: raw["suppress"],
      request_to_speak_timestamp: EDA.Timestamp.parse(raw["request_to_speak_timestamp"])
    }
  end

  defp parse_member(nil), do: nil
  defp parse_member(raw) when is_map(raw), do: EDA.Member.from_raw(raw)
end
