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
    EDA.HTTP.Client.get(with_query("/guilds/#{guild_id}/members", opts))
  end

  @doc "Searches guild members by username/nickname."
  @spec search(String.t() | integer(), String.t(), keyword()) ::
          {:ok, [map()]} | {:error, term()}
  def search(guild_id, query, opts \\ []) do
    EDA.HTTP.Client.get(
      with_query("/guilds/#{guild_id}/members/search", [{:query, query} | opts])
    )
  end

  @doc "Modifies a guild member."
  @spec modify(String.t() | integer(), String.t() | integer(), map(), keyword()) ::
          {:ok, map()} | {:error, term()}
  def modify(guild_id, user_id, payload, opts \\ []) do
    patch("/guilds/#{guild_id}/members/#{user_id}", payload, opts)
  end

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
