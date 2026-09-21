defmodule EDA.API.Soundboard do
  @moduledoc """
  REST API endpoints for soundboard sounds.

  All functions return raw maps: `{:ok, map}` or `{:error, reason}`. `EDA.SoundboardSound`
  wraps the reads in structs.

  A soundboard sound is either one of Discord's defaults, available everywhere, or belongs to
  a guild. Guild sounds are managed with `create/2`, `modify/3` and `delete/3`, which need the
  `CREATE_GUILD_EXPRESSIONS` or `MANAGE_GUILD_EXPRESSIONS` permission, and played into a voice
  channel with `send_sound/3`.

  The create, modify and delete routes accept `:reason`, sent as the audit log reason.
  """

  import EDA.HTTP.Client

  @create_keys ~w(name sound volume emoji_id emoji_name reason)a
  @modify_keys ~w(name volume emoji_id emoji_name reason)a
  @send_keys ~w(source_guild_id)a

  @doc """
  Lists the default soundboard sounds, available to every user.

  `GET /soundboard-default-sounds`
  """
  @spec default_sounds() :: {:ok, [map()]} | {:error, term()}
  def default_sounds, do: EDA.HTTP.Client.get("/soundboard-default-sounds")

  @doc """
  Lists a guild's soundboard sounds.

  `GET /guilds/{guild_id}/soundboard-sounds`. Discord wraps the list as `%{"items" => [...]}`;
  this returns the list itself. Each sound carries its creator in `"user"` only when the bot
  has `CREATE_GUILD_EXPRESSIONS` or `MANAGE_GUILD_EXPRESSIONS`.
  """
  @spec list(String.t() | integer()) :: {:ok, [map()]} | {:error, term()}
  def list(guild_id) do
    case EDA.HTTP.Client.get("/guilds/#{guild_id}/soundboard-sounds") do
      {:ok, %{"items" => items}} -> {:ok, items}
      other -> other
    end
  end

  @doc "Gets one of a guild's soundboard sounds."
  @spec get(String.t() | integer(), String.t() | integer()) :: {:ok, map()} | {:error, term()}
  def get(guild_id, sound_id) do
    EDA.HTTP.Client.get("/guilds/#{guild_id}/soundboard-sounds/#{sound_id}")
  end

  @doc """
  Creates a guild soundboard sound. Requires `CREATE_GUILD_EXPRESSIONS`.

  ## Options

    * `:name` — required, 2–32 characters
    * `:sound` — required: a path, raw MP3 or Ogg bytes, or a data URI; see `EDA.SoundData`.
      At most 512 KiB and 5.2 seconds
    * `:volume` — 0 to 1, defaults to 1
    * `:emoji_id` — a custom emoji for the sound
    * `:emoji_name` — or a standard emoji, as its unicode character
    * `:reason` — audit log reason

  ## Example

      EDA.API.Soundboard.create(guild_id, name: "airhorn", sound: "priv/airhorn.mp3", emoji_name: "📯")
  """
  @spec create(String.t() | integer(), keyword() | map()) :: {:ok, map()} | {:error, term()}
  def create(guild_id, opts) do
    opts = Map.new(opts)
    check_options!(opts, @create_keys, "EDA.API.Soundboard.create/2")

    for key <- [:name, :sound], not Map.has_key?(opts, key) do
      raise ArgumentError, "EDA.API.Soundboard.create/2 requires :#{key}"
    end

    {reason, body} = Map.pop(opts, :reason)
    validate_name!(body[:name])
    validate_volume!(body[:volume])
    body = Map.update!(body, :sound, &EDA.SoundData.coerce/1)

    post("/guilds/#{guild_id}/soundboard-sounds", body, reason_opts(reason))
  end

  @doc """
  Modifies a guild soundboard sound.

  A sound the bot created needs `CREATE_GUILD_EXPRESSIONS` or `MANAGE_GUILD_EXPRESSIONS`; any
  other needs `MANAGE_GUILD_EXPRESSIONS`. The audio itself cannot be changed.

  ## Options

  `:name`, `:volume`, `:emoji_id`, `:emoji_name` and `:reason`, as for `create/2`. A `nil`
  volume or emoji clears it.
  """
  @spec modify(String.t() | integer(), String.t() | integer(), keyword() | map()) ::
          {:ok, map()} | {:error, term()}
  def modify(guild_id, sound_id, opts) do
    opts = Map.new(opts)
    check_options!(opts, @modify_keys, "EDA.API.Soundboard.modify/3")

    {reason, body} = Map.pop(opts, :reason)
    if Map.has_key?(body, :name), do: validate_name!(body.name)
    validate_volume!(body[:volume])

    patch("/guilds/#{guild_id}/soundboard-sounds/#{sound_id}", body, reason_opts(reason))
  end

  @doc """
  Deletes a guild soundboard sound. Same permissions as `modify/3`.

  ## Options

    * `:reason` — audit log reason
  """
  @spec delete(String.t() | integer(), String.t() | integer(), keyword()) ::
          :ok | {:error, term()}
  def delete(guild_id, sound_id, opts \\ []) do
    check_options!(opts, [:reason], "EDA.API.Soundboard.delete/3")

    case EDA.HTTP.Client.delete(
           "/guilds/#{guild_id}/soundboard-sounds/#{sound_id}",
           reason_opts(opts[:reason])
         ) do
      {:ok, _} -> :ok
      error -> error
    end
  end

  @doc """
  Plays a soundboard sound into a voice channel.

  `POST /channels/{channel_id}/send-soundboard-sound`. Discord only accepts it from a user
  **in** that channel, and neither muted, deafened nor suppressed — so the bot must have
  joined it with `EDA.Voice.join/2` first. Requires `SPEAK` and `USE_SOUNDBOARD`, plus
  `USE_EXTERNAL_SOUNDS` for a sound from another guild. Everyone connected receives a
  `VOICE_CHANNEL_EFFECT_SEND` event.

  ## Options

    * `:source_guild_id` — the guild the sound belongs to, required to play one from another
      guild. Not needed for a default sound or one from this channel's guild

  ## Example

      EDA.API.Soundboard.send_sound(channel_id, "1")   # a default sound
  """
  @spec send_sound(String.t() | integer(), String.t() | integer(), keyword()) ::
          :ok | {:error, term()}
  def send_sound(channel_id, sound_id, opts \\ []) do
    check_options!(opts, @send_keys, "EDA.API.Soundboard.send_sound/3")

    body =
      opts
      |> Map.new(fn {k, v} -> {k, to_string(v)} end)
      |> Map.put(:sound_id, to_string(sound_id))

    case post("/channels/#{channel_id}/send-soundboard-sound", body) do
      {:ok, _} -> :ok
      error -> error
    end
  end

  defp reason_opts(nil), do: []
  defp reason_opts(reason), do: [reason: reason]

  defp validate_name!(name) when is_binary(name) do
    length = String.length(name)

    unless length in 2..32 do
      raise ArgumentError, "a soundboard sound's name is 2–32 characters, got #{length}"
    end
  end

  defp validate_name!(other),
    do: raise(ArgumentError, "a soundboard sound's name must be a string, got: #{inspect(other)}")

  defp validate_volume!(nil), do: :ok

  defp validate_volume!(volume) when is_number(volume) and volume >= 0 and volume <= 1, do: :ok

  defp validate_volume!(other),
    do: raise(ArgumentError, "volume is from 0 to 1, got: #{inspect(other)}")
end
