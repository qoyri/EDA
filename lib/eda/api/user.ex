defmodule EDA.API.User do
  @moduledoc """
  REST API endpoints for Discord users.

  All functions return `{:ok, result}` or `{:error, reason}`.
  """

  import EDA.HTTP.Client

  @doc "Gets the current bot user."
  @spec me() :: {:ok, map()} | {:error, term()}
  def me do
    EDA.HTTP.Client.get("/users/@me")
  end

  @doc """
  Modifies the current bot user — its account-wide identity.

  `PATCH /users/@me`, taking `username`, `avatar` and `banner`. A per-guild profile is set
  with `EDA.API.Member.modify_me/2` instead, and overrides this one in that guild.

  `avatar` and `banner` are *image data*: a path or raw bytes is converted to a data URI
  for you, and `nil` clears the field. See `EDA.ImageData`.

      EDA.API.User.modify_me(%{username: "EDA", avatar: "priv/avatar.png"})

  Changing the username may randomise the discriminator, and Discord rate-limits it
  heavily — this is not a call to make on a schedule.
  """
  @spec modify_me(map() | keyword()) :: {:ok, map()} | {:error, term()}
  def modify_me(opts) when is_list(opts) do
    opts |> Map.new() |> modify_me()
  end

  def modify_me(payload) when is_map(payload) do
    check_options!(payload, [:username, :avatar, :banner], "EDA.API.User.modify_me/1")
    patch("/users/@me", Map.new(payload, &coerce_image_field/1))
  end

  defp coerce_image_field({key, value}) when key in [:avatar, :banner, "avatar", "banner"] do
    {key, EDA.ImageData.coerce(value)}
  end

  defp coerce_image_field(pair), do: pair

  @doc "Gets a user by ID."
  @spec get(String.t() | integer()) :: {:ok, map()} | {:error, term()}
  def get(user_id) do
    EDA.HTTP.Client.get("/users/#{user_id}")
  end

  @doc "Creates a DM channel with a user."
  @spec create_dm(String.t() | integer()) :: {:ok, map()} | {:error, term()}
  def create_dm(user_id) do
    post("/users/@me/channels", %{recipient_id: user_id})
  end

  @guild_keys ~w(before after limit with_counts shard)a

  @doc """
  Lists the guilds the bot is in, as partial guild objects.

  `GET /users/@me/guilds`. Returns at most 200 per call; `stream_guilds/1` pages through them
  all.

  ## Options

    * `:before`, `:after` — guild id cursors
    * `:limit` — 1–200, default 200
    * `:with_counts` — include `approximate_member_count` and `approximate_presence_count`
    * `:shard` — only the guilds of this shard, `0` to `max_concurrency - 1`. **Required** for a
      bot using large bot sharding: Discord answers `400` without it since September 2026
  """
  @spec guilds(keyword()) :: {:ok, [map()]} | {:error, term()}
  def guilds(opts \\ []) do
    EDA.HTTP.Client.get(with_query("/users/@me/guilds", opts, @guild_keys))
  end

  @doc """
  Streams every guild the bot is in, 200 per request, lazily.

  Takes the options of `guilds/1` except `:before`, `:after` and `:limit`.

      EDA.API.User.stream_guilds(with_counts: true) |> Enum.count()
  """
  @spec stream_guilds(keyword()) :: Enumerable.t()
  def stream_guilds(opts \\ []) do
    check_options!(opts, [:with_counts, :shard], "EDA.API.User.stream_guilds/1")

    EDA.Paginator.stream(
      fetch: fn cursor ->
        guilds(opts ++ [limit: 200] ++ if(cursor, do: [after: cursor], else: []))
      end,
      direction: :after,
      per_page: 200
    )
  end

  @doc """
  Leaves a guild. Discord then sends `GUILD_DELETE` for it.

  `DELETE /users/@me/guilds/{guild_id}`. The bot cannot leave a guild it owns.
  """
  @spec leave_guild(String.t() | integer()) :: :ok | {:error, term()}
  def leave_guild(guild_id) do
    case EDA.HTTP.Client.delete("/users/@me/guilds/#{guild_id}") do
      {:ok, _} -> :ok
      error -> error
    end
  end
end
