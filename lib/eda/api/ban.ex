defmodule EDA.API.Ban do
  @moduledoc """
  REST API endpoints for Discord guild bans.

  All functions return `{:ok, result}` or `{:error, reason}`.
  """

  import EDA.HTTP.Client

  @doc "Gets bans for a guild."
  @spec list(String.t() | integer(), keyword()) :: {:ok, [map()]} | {:error, term()}
  def list(guild_id, opts \\ []) do
    EDA.HTTP.Client.get(with_query("/guilds/#{guild_id}/bans", opts))
  end

  @doc "Gets a specific ban for a guild."
  @spec get(String.t() | integer(), String.t() | integer()) ::
          {:ok, map()} | {:error, term()}
  def get(guild_id, user_id) do
    EDA.HTTP.Client.get("/guilds/#{guild_id}/bans/#{user_id}")
  end

  @doc """
  Bans a user from a guild.

  ## Options

    * `:delete_message_seconds` — seconds of message history to delete (0-604800)
    * `:reason` — audit log reason (sent as `X-Audit-Log-Reason` header)
  """
  @spec create(String.t() | integer(), String.t() | integer(), keyword()) ::
          :ok | {:error, term()}
  def create(guild_id, user_id, opts \\ []) do
    {reason, opts} = Keyword.pop(opts, :reason)

    body =
      opts
      |> Enum.reject(fn {_, v} -> is_nil(v) end)
      |> Map.new()

    case put("/guilds/#{guild_id}/bans/#{user_id}", body, priority: :urgent, reason: reason) do
      {:ok, _} -> :ok
      error -> error
    end
  end

  @doc "Unbans a user from a guild."
  @spec remove(String.t() | integer(), String.t() | integer()) :: :ok | {:error, term()}
  def remove(guild_id, user_id) do
    case EDA.HTTP.Client.delete("/guilds/#{guild_id}/bans/#{user_id}", priority: :urgent) do
      {:ok, _} -> :ok
      error -> error
    end
  end

  @doc """
  Returns a lazy `Stream` that paginates through all bans in a guild.

  ## Options

  - `:direction` — `:before` or `:after` (default `:before`)
  - `:per_page` — bans per request (1-1000, default 1000)
  - `:before` — start before this user ID
  - `:after` — start after this user ID

  ## Examples

      EDA.API.Ban.stream(guild_id) |> Enum.to_list()
      EDA.API.Ban.stream(guild_id, per_page: 100) |> Stream.take(50) |> Enum.to_list()
  """
  @spec stream(String.t() | integer(), keyword()) :: Enumerable.t()
  def stream(guild_id, opts \\ []) do
    per_page = Keyword.get(opts, :per_page, 1000)
    direction = if opts[:after], do: :after, else: :before
    initial_cursor = opts[:before] || opts[:after]

    EDA.Paginator.stream(
      fetch: fn cursor ->
        query = [limit: per_page] ++ if(cursor, do: [{direction, cursor}], else: [])
        list(guild_id, query)
      end,
      cursor_key: ["user", "id"],
      direction: direction,
      per_page: per_page,
      initial_cursor: initial_cursor
    )
  end

  @doc """
  Bans up to 200 users from a guild in a single request.

  ## Options
  - `:delete_message_seconds` - Seconds of messages to delete (0-604800)

  Returns `{:ok, %{"banned_users" => [...], "failed_users" => [...]}}`.
  """
  @spec bulk(String.t() | integer(), [String.t() | integer()], keyword()) ::
          {:ok, map()} | {:error, term()}
  def bulk(guild_id, user_ids, opts \\ []) do
    if length(user_ids) > 200 do
      {:error, :too_many_users}
    else
      body =
        %{user_ids: Enum.map(user_ids, &to_string/1)}
        |> maybe_put(:delete_message_seconds, opts[:delete_message_seconds])

      post("/guilds/#{guild_id}/bulk-ban", body, priority: :urgent)
    end
  end
end
