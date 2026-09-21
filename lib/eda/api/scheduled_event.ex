defmodule EDA.API.ScheduledEvent do
  @moduledoc """
  REST API endpoints for Discord guild scheduled events.

  All functions return `{:ok, result}` or `{:error, reason}`.
  """

  import EDA.HTTP.Client

  @doc """
  Lists scheduled events for a guild.

  ## Options
  - `:with_user_count` - Include user count (boolean)
  """
  @spec list(String.t() | integer(), keyword()) :: {:ok, [map()]} | {:error, term()}
  def list(guild_id, opts \\ []) do
    EDA.HTTP.Client.get(
      with_query("/guilds/#{guild_id}/scheduled-events", opts, [:with_user_count])
    )
  end

  @doc """
  Gets a scheduled event by ID.

  ## Options
  - `:with_user_count` - Include user count (boolean)
  """
  @spec get(String.t() | integer(), String.t() | integer(), keyword()) ::
          {:ok, map()} | {:error, term()}
  def get(guild_id, event_id, opts \\ []) do
    EDA.HTTP.Client.get(
      with_query("/guilds/#{guild_id}/scheduled-events/#{event_id}", opts, [:with_user_count])
    )
  end

  @doc "Creates a scheduled event in a guild."
  @spec create(String.t() | integer(), map()) :: {:ok, map()} | {:error, term()}
  def create(guild_id, params) do
    post("/guilds/#{guild_id}/scheduled-events", params)
  end

  @doc "Modifies a scheduled event."
  @spec modify(String.t() | integer(), String.t() | integer(), map()) ::
          {:ok, map()} | {:error, term()}
  def modify(guild_id, event_id, params) do
    patch("/guilds/#{guild_id}/scheduled-events/#{event_id}", params)
  end

  @doc "Deletes a scheduled event."
  @spec delete(String.t() | integer(), String.t() | integer()) :: :ok | {:error, term()}
  def delete(guild_id, event_id) do
    case EDA.HTTP.Client.delete("/guilds/#{guild_id}/scheduled-events/#{event_id}") do
      {:ok, _} -> :ok
      error -> error
    end
  end

  @doc """
  Returns a lazy `Stream` that paginates through users subscribed to a scheduled event.

  ## Options

  - `:direction` — `:before` or `:after` (default `:before`)
  - `:per_page` — users per request (1-100, default 100)
  - `:before` — start before this user ID
  - `:after` — start after this user ID
  - `:with_member` — include guild member data (boolean)

  ## Examples

      EDA.API.ScheduledEvent.user_stream(guild_id, event_id) |> Enum.to_list()
      EDA.API.ScheduledEvent.user_stream(guild_id, event_id, with_member: true)
      |> Stream.take(50) |> Enum.to_list()
  """
  @spec user_stream(String.t() | integer(), String.t() | integer(), keyword()) ::
          Enumerable.t()
  def user_stream(guild_id, event_id, opts \\ []) do
    per_page = Keyword.get(opts, :per_page, 100)
    direction = if opts[:after], do: :after, else: :before
    initial_cursor = opts[:before] || opts[:after]
    extra = if opts[:with_member], do: [with_member: true], else: []

    EDA.Paginator.stream(
      fetch: fn cursor ->
        query = [limit: per_page] ++ extra ++ if(cursor, do: [{direction, cursor}], else: [])
        users(guild_id, event_id, query)
      end,
      cursor_key: ["user", "id"],
      direction: direction,
      per_page: per_page,
      initial_cursor: initial_cursor
    )
  end

  @doc """
  Gets users subscribed to a scheduled event.

  ## Options
  - `:limit` - Number of users (1-100, default 100)
  - `:with_member` - Include guild member data (boolean)
  - `:before` - Get users before this user ID
  - `:after` - Get users after this user ID
  """
  @spec users(String.t() | integer(), String.t() | integer(), keyword()) ::
          {:ok, [map()]} | {:error, term()}
  def users(guild_id, event_id, opts \\ []) do
    EDA.HTTP.Client.get(
      with_query("/guilds/#{guild_id}/scheduled-events/#{event_id}/users", opts, [
        :limit,
        :with_member,
        :before,
        :after
      ])
    )
  end
end
