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
  def from_raw(%__MODULE__{} = parsed), do: parsed

  def from_raw(raw) when is_map(raw) do
    %__MODULE__{
      guild_id: :maps.get("guild_id", raw, nil),
      channel_id: :maps.get("channel_id", raw, nil),
      user_id: :maps.get("user_id", raw, nil),
      member: parse_member(:maps.get("member", raw, nil)),
      session_id: :maps.get("session_id", raw, nil),
      deaf: :maps.get("deaf", raw, nil),
      mute: :maps.get("mute", raw, nil),
      self_deaf: :maps.get("self_deaf", raw, nil),
      self_mute: :maps.get("self_mute", raw, nil),
      self_stream: :maps.get("self_stream", raw, nil),
      self_video: :maps.get("self_video", raw, nil),
      suppress: :maps.get("suppress", raw, nil),
      request_to_speak_timestamp:
        EDA.Timestamp.parse(:maps.get("request_to_speak_timestamp", raw, nil))
    }
  end

  defp parse_member(nil), do: nil
  defp parse_member(raw) when is_map(raw), do: EDA.Member.from_raw(raw)

  @doc """
  Fetches a user's voice state in a guild, or the bot's with `:me`, from Discord rather than
  the cache.

  Named `fetch_state/2` rather than `fetch/2` because `Access.fetch/2` owns that arity.
  """
  @spec fetch_state(String.t() | integer(), :me | String.t() | integer()) ::
          {:ok, t()} | {:error, term()}
  def fetch_state(guild_id, user) do
    case EDA.API.Voice.voice_state(guild_id, user) do
      {:ok, raw} when is_map(raw) ->
        {:ok, from_raw(Map.put_new(raw, "guild_id", to_string(guild_id)))}

      {:error, _} = err ->
        err
    end
  end

  @doc """
  Whether the user cannot be heard: muted by themselves or by the guild, or suppressed on a
  stage.
  """
  @spec muted?(t()) :: boolean()
  def muted?(%__MODULE__{mute: mute, self_mute: self_mute, suppress: suppress}),
    do: mute == true or self_mute == true or suppress == true

  @doc "Whether the user cannot hear: deafened by themselves or by the guild."
  @spec deafened?(t()) :: boolean()
  def deafened?(%__MODULE__{deaf: deaf, self_deaf: self_deaf}),
    do: deaf == true or self_deaf == true
end
