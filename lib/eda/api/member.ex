defmodule EDA.API.Member do
  @moduledoc """
  REST API endpoints for Discord guild members.

  All functions return `{:ok, result}` or `{:error, reason}`.
  """

  import EDA.HTTP.Client

  @doc "Gets a member of a guild."
  @spec get(String.t() | integer(), String.t() | integer()) ::
          {:ok, map()} | {:error, term()}
  def get(guild_id, user_id) do
    EDA.HTTP.Client.get("/guilds/#{guild_id}/members/#{user_id}")
  end

  @doc "Lists members of a guild."
  @spec list(String.t() | integer(), keyword()) :: {:ok, [map()]} | {:error, term()}
  def list(guild_id, opts \\ []) do
    EDA.HTTP.Client.get(with_query("/guilds/#{guild_id}/members", opts, [:limit, :after]))
  end

  @doc "Searches guild members by username/nickname."
  @spec search(String.t() | integer(), String.t(), keyword()) ::
          {:ok, [map()]} | {:error, term()}
  def search(guild_id, query, opts \\ []) do
    EDA.HTTP.Client.get(
      with_query("/guilds/#{guild_id}/members/search", [{:query, query} | opts], [:query, :limit])
    )
  end

  @doc "Modifies a guild member."
  @spec modify(String.t() | integer(), String.t() | integer(), map(), keyword()) ::
          {:ok, map()} | {:error, term()}
  def modify(guild_id, user_id, payload, opts \\ []) do
    patch("/guilds/#{guild_id}/members/#{user_id}", payload, opts)
  end

  @doc """
  Modifies the bot's own member in a guild — its per-guild profile.

  `PATCH /guilds/{guild_id}/members/@me`. This is a different endpoint from `modify/4`, and
  the only one that can set the bot's avatar, banner and bio *for one guild*. The bot keeps
  its account-wide identity from `EDA.API.User.modify_me/1`; what is set here overrides it
  in this guild alone.

  ## Options

    * `:nick` - guild nickname. The only field that needs a permission: `CHANGE_NICKNAME`
    * `:avatar` - guild avatar, as image data
    * `:banner` - guild banner, as image data
    * `:bio` - guild bio
    * `:reason` - audit log reason

  Pass `nil` for any of them to clear it and fall back to the account-wide value. Fields
  you leave out are untouched, so setting a bio alone keeps the avatar and banner.

  `bio` is echoed by this endpoint's own response but is **not** part of the guild member
  object Discord returns from `get/2` — reading the member back will not give it to you.

  ## Images

  `:avatar` and `:banner` are *image data*, a base64 data URI rather than a file upload.
  A path or raw bytes is converted for you, and the media type comes from the bytes rather
  than the extension — see `EDA.ImageData`:

      EDA.API.Member.modify_me(guild_id,
        nick: "EDA",
        avatar: "priv/avatar.png",
        bio: "Built on OTP",
        reason: "profile refresh"
      )

      # clears the guild avatar, restoring the account-wide one
      EDA.API.Member.modify_me(guild_id, avatar: nil)

  """
  @spec modify_me(String.t() | integer(), map() | keyword()) :: {:ok, map()} | {:error, term()}
  def modify_me(guild_id, opts \\ [])

  def modify_me(guild_id, opts) when is_list(opts) do
    {reason, opts} = Keyword.pop(opts, :reason)

    payload =
      opts
      |> Keyword.take([:nick, :avatar, :banner, :bio])
      |> Enum.map(&coerce_profile_field/1)
      |> Map.new()

    patch("/guilds/#{guild_id}/members/@me", payload, reason_opts(reason))
  end

  def modify_me(guild_id, payload) when is_map(payload) do
    {reason, payload} = Map.pop(payload, :reason)

    payload =
      payload
      |> Enum.map(&coerce_profile_field/1)
      |> Map.new()

    patch("/guilds/#{guild_id}/members/@me", payload, reason_opts(reason))
  end

  # Only the image fields need coercion; a nil stays nil, because Discord reads it as "clear".
  defp coerce_profile_field({key, value}) when key in [:avatar, :banner, "avatar", "banner"] do
    {key, EDA.ImageData.coerce(value)}
  end

  defp coerce_profile_field(pair), do: pair

  defp reason_opts(nil), do: []
  defp reason_opts(reason), do: [reason: reason]

  @doc "Removes a member from a guild (kick)."
  @spec remove(String.t() | integer(), String.t() | integer(), keyword()) ::
          :ok | {:error, term()}
  def remove(guild_id, user_id, opts \\ []) do
    case EDA.HTTP.Client.delete(
           "/guilds/#{guild_id}/members/#{user_id}",
           Keyword.put_new(opts, :priority, :urgent)
         ) do
      {:ok, _} -> :ok
      error -> error
    end
  end

  @doc """
  Returns a lazy `Stream` that paginates through all members of a guild.

  Uses after-only pagination (Discord constraint for the members endpoint).

  ## Options

  - `:per_page` — members per request (1-1000, default 1000)
  - `:after` — start after this user ID

  ## Examples

      EDA.API.Member.stream(guild_id) |> Enum.to_list()
      EDA.API.Member.stream(guild_id) |> Stream.filter(&(&1["user"]["bot"])) |> Enum.to_list()
  """
  @spec stream(String.t() | integer(), keyword()) :: Enumerable.t()
  def stream(guild_id, opts \\ []) do
    per_page = Keyword.get(opts, :per_page, 1000)
    initial_cursor = opts[:after]

    EDA.Paginator.stream(
      fetch: fn cursor ->
        query = [limit: per_page] ++ if(cursor, do: [after: cursor], else: [])
        list(guild_id, query)
      end,
      cursor_key: ["user", "id"],
      direction: :after,
      per_page: per_page,
      initial_cursor: initial_cursor
    )
  end

  @doc "Adds a role to a guild member."
  @spec add_role(
          String.t() | integer(),
          String.t() | integer(),
          String.t() | integer(),
          keyword()
        ) :: :ok | {:error, term()}
  def add_role(guild_id, user_id, role_id, opts \\ []) do
    case put("/guilds/#{guild_id}/members/#{user_id}/roles/#{role_id}", %{}, opts) do
      {:ok, _} -> :ok
      error -> error
    end
  end

  @doc "Removes a role from a guild member."
  @spec remove_role(
          String.t() | integer(),
          String.t() | integer(),
          String.t() | integer(),
          keyword()
        ) :: :ok | {:error, term()}
  def remove_role(guild_id, user_id, role_id, opts \\ []) do
    case EDA.HTTP.Client.delete(
           "/guilds/#{guild_id}/members/#{user_id}/roles/#{role_id}",
           opts
         ) do
      {:ok, _} -> :ok
      error -> error
    end
  end

  @doc """
  Moves a member to a different voice channel.

  Pass `nil` as `channel_id` to disconnect the user from voice.

  ## Examples

      EDA.API.Member.move_voice(guild_id, user_id, new_channel_id)
      EDA.API.Member.move_voice(guild_id, user_id, nil)  # disconnect
  """
  @spec move_voice(
          String.t() | integer(),
          String.t() | integer(),
          String.t() | integer() | nil
        ) :: {:ok, map()} | {:error, term()}
  def move_voice(guild_id, user_id, channel_id) do
    modify(guild_id, user_id, %{channel_id: channel_id})
  end
end
