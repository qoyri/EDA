defmodule EDA.SoundboardSound do
  @moduledoc """
  A soundboard sound: one of Discord's defaults, available to everyone, or a guild's own.

      {:ok, sounds} = EDA.SoundboardSound.list(guild_id)
      sound = Enum.find(sounds, &(&1.name == "airhorn"))
      EDA.SoundboardSound.play(sound, voice_channel_id)

  `guild_id` is `nil` for a default sound. `available` goes `false` when a guild loses the
  Server Boost level that allowed the sound. Default sound ids are small integers
  (`"1"`, `"2"`, …) rather than snowflakes.

  The audio is served as MP3 or Ogg at `url/1`. Playing a sound needs the bot in the voice
  channel — see `play/3`. Managing guild sounds is in `EDA.API.Soundboard`.

  ## Over the gateway

  A guild's sounds arrive in `GUILD_CREATE` (`soundboard_sounds`), and changes arrive as
  `GUILD_SOUNDBOARD_SOUND_CREATE`, `_UPDATE`, `_DELETE` and `GUILD_SOUNDBOARD_SOUNDS_UPDATE`,
  under the `:guild_expressions` intent. `request/1` asks the gateway for the sounds of
  several guilds at once, answered by one `SOUNDBOARD_SOUNDS` event per guild. EDA does not
  cache soundboard sounds; the events carry them.
  """

  use EDA.Event.Access

  defstruct [:sound_id, :name, :volume, :emoji_id, :emoji_name, :guild_id, :available, :user]

  @type t :: %__MODULE__{
          sound_id: String.t() | nil,
          name: String.t() | nil,
          volume: float() | nil,
          emoji_id: String.t() | nil,
          emoji_name: String.t() | nil,
          guild_id: String.t() | nil,
          available: boolean() | nil,
          user: EDA.User.t() | nil
        }

  @cdn "https://cdn.discordapp.com"

  @doc """
  Converts a raw soundboard sound map into this struct.

      iex> EDA.SoundboardSound.from_raw(%{"sound_id" => "1", "name" => "quack", "volume" => 1.0, "emoji_name" => "🦆", "available" => true})
      %EDA.SoundboardSound{sound_id: "1", name: "quack", volume: 1.0, emoji_name: "🦆", available: true}
  """
  @spec from_raw(map()) :: t()
  def from_raw(raw) when is_map(raw) do
    %__MODULE__{
      sound_id: id(raw["sound_id"]),
      name: raw["name"],
      volume: raw["volume"],
      emoji_id: raw["emoji_id"],
      emoji_name: raw["emoji_name"],
      guild_id: raw["guild_id"],
      available: raw["available"],
      user: parse_user(raw["user"])
    }
  end

  @doc """
  The URL of the sound's audio file, MP3 or Ogg.

      iex> EDA.SoundboardSound.url(%EDA.SoundboardSound{sound_id: "1"})
      "https://cdn.discordapp.com/soundboard-sounds/1"
  """
  @spec url(t()) :: String.t()
  def url(%__MODULE__{sound_id: id}), do: "#{@cdn}/soundboard-sounds/#{id}"

  @doc """
  Whether this is one of Discord's default sounds rather than a guild's.

      iex> EDA.SoundboardSound.default?(%EDA.SoundboardSound{sound_id: "1", guild_id: nil})
      true
  """
  @spec default?(t()) :: boolean()
  def default?(%__MODULE__{guild_id: guild_id}), do: is_nil(guild_id)

  # ── Entity Manager ─────────────────────────────────────────────────

  @doc "Lists Discord's default sounds, as structs."
  @spec default_sounds() :: {:ok, [t()]} | {:error, term()}
  def default_sounds, do: map_list(EDA.API.Soundboard.default_sounds())

  @doc "Lists a guild's soundboard sounds, as structs."
  @spec list(String.t() | integer()) :: {:ok, [t()]} | {:error, term()}
  def list(guild_id), do: map_list(EDA.API.Soundboard.list(guild_id))

  @doc "Fetches one of a guild's soundboard sounds."
  @spec fetch_sound(String.t() | integer(), String.t() | integer()) ::
          {:ok, t()} | {:error, term()}
  def fetch_sound(guild_id, sound_id) do
    case EDA.API.Soundboard.get(guild_id, sound_id) do
      {:ok, raw} -> {:ok, from_raw(raw)}
      error -> error
    end
  end

  @doc """
  Plays a sound into a voice channel the bot has joined.

  Takes a struct or a sound id. For a guild sound played in another guild's channel, the
  struct supplies the source guild; with a bare id, pass `source_guild_id:`. See
  `EDA.API.Soundboard.send_sound/3` for the permissions and voice state Discord requires.

      :ok = EDA.Voice.join(guild_id, channel_id)
      EDA.SoundboardSound.play(sound, channel_id)
  """
  @spec play(t() | String.t() | integer(), String.t() | integer(), keyword()) ::
          :ok | {:error, term()}
  def play(sound, channel_id, opts \\ [])

  def play(%__MODULE__{sound_id: id, guild_id: guild_id}, channel_id, opts) do
    opts = if guild_id, do: Keyword.put_new(opts, :source_guild_id, guild_id), else: opts
    EDA.API.Soundboard.send_sound(channel_id, id, opts)
  end

  def play(sound_id, channel_id, opts),
    do: EDA.API.Soundboard.send_sound(channel_id, sound_id, opts)

  @doc """
  Asks the gateway for the soundboard sounds of several guilds (opcode 31).

  Each guild is answered by a `SOUNDBOARD_SOUNDS` event — an `EDA.Event.SoundboardSounds`
  holding its sounds. Requests go out on the shard that owns each guild. Returns `:ok` once
  sent; it does not wait for the answers.

      EDA.SoundboardSound.request(["613425648685547541", "81384788765712384"])
  """
  @spec request([String.t() | integer()]) :: :ok
  def request(guild_ids) when is_list(guild_ids) do
    EDA.Gateway.Connection.request_soundboard_sounds(guild_ids)
  end

  defp map_list({:ok, list}) when is_list(list), do: {:ok, Enum.map(list, &from_raw/1)}
  defp map_list(error), do: error

  # Default sounds may carry their id as an integer.
  defp id(nil), do: nil
  defp id(id), do: to_string(id)

  defp parse_user(nil), do: nil
  defp parse_user(user) when is_map(user), do: EDA.User.from_raw(user)
end
