defmodule EDA.API.Voice do
  @moduledoc """
  REST API endpoints for voice: regions, and voice states in Stage channels.

  All functions return raw maps: `{:ok, map}` or `{:error, reason}`. Joining and leaving voice
  goes through the gateway — see `EDA.Voice`.
  """

  import EDA.HTTP.Client

  @doc """
  Lists the voice regions a voice or Stage channel's `rtc_region` can be set to.

  `GET /voice/regions`. `EDA.API.Guild.voice_regions/1` adds a guild's VIP regions.
  """
  @spec regions() :: {:ok, [map()]} | {:error, term()}
  def regions, do: EDA.HTTP.Client.get("/voice/regions")

  @doc """
  Gets a voice state in a guild: the bot's own with `:me`, or a user's.

  `GET /guilds/{guild_id}/voice-states/@me` or `/voice-states/{user_id}`. Answers `404` when the
  user is not in a voice channel of that guild.
  """
  @spec voice_state(String.t() | integer(), :me | String.t() | integer()) ::
          {:ok, map()} | {:error, term()}
  def voice_state(guild_id, user), do: EDA.HTTP.Client.get(path(guild_id, user))

  @doc """
  Changes a voice state in a Stage channel: the bot's own with `:me`, or a user's.

  `PATCH /guilds/{guild_id}/voice-states/@me` or `/{user_id}`. Discord only allows this in a
  Stage channel the user has already joined, so `:channel_id` must be that Stage channel.

  ## Options

    * `:channel_id` — the Stage channel the user is in (required by Discord)
    * `:suppress` — `false` to move the user to the speakers, `true` back to the audience.
      Unsuppressing needs `MUTE_MEMBERS`; the bot can always suppress itself
    * `:request_to_speak_timestamp` — `:me` only: raise the bot's hand, as a `DateTime` or an
      ISO8601 string (now or later), or `nil` to lower it. Needs `REQUEST_TO_SPEAK`

  ## Example

      # Put the bot on stage
      EDA.API.Voice.modify_voice_state(guild_id, :me, channel_id: stage_id, suppress: false)
  """
  @spec modify_voice_state(String.t() | integer(), :me | String.t() | integer(), keyword()) ::
          :ok | {:error, term()}
  def modify_voice_state(guild_id, user, opts) do
    allowed = [
      :channel_id,
      :suppress | if(user == :me, do: [:request_to_speak_timestamp], else: [])
    ]

    check_options!(opts, allowed, "EDA.API.Voice.modify_voice_state/3")

    body = Map.new(opts, fn {key, value} -> {key, encode_field(key, value)} end)

    case patch(path(guild_id, user), body) do
      {:ok, _} -> :ok
      error -> error
    end
  end

  defp encode_field(:channel_id, id) when is_integer(id), do: Integer.to_string(id)
  defp encode_field(:request_to_speak_timestamp, %DateTime{} = at), do: DateTime.to_iso8601(at)
  defp encode_field(_key, value), do: value

  defp path(guild_id, :me), do: "/guilds/#{guild_id}/voice-states/@me"
  defp path(guild_id, user_id), do: "/guilds/#{guild_id}/voice-states/#{user_id}"
end
