defmodule EDA.API.Reaction do
  @moduledoc """
  REST API endpoints for Discord message reactions.

  All functions return `:ok` or `{:ok, result}` or `{:error, reason}`.
  The `emoji` parameter accepts a string (`"👍"` or `"name:id"`) or an `EDA.Emoji` struct.
  """

  import EDA.HTTP.Client

  @doc "Adds a reaction to a message."
  @spec create(String.t() | integer(), String.t() | integer(), String.t() | EDA.Emoji.t()) ::
          :ok | {:error, term()}
  def create(channel_id, message_id, emoji) do
    emoji = emoji |> resolve_emoji() |> URI.encode()

    case put("/channels/#{channel_id}/messages/#{message_id}/reactions/#{emoji}/@me", %{}) do
      {:ok, _} -> :ok
      error -> error
    end
  end

  @doc "Removes own reaction from a message."
  @spec delete_own(String.t() | integer(), String.t() | integer(), String.t() | EDA.Emoji.t()) ::
          :ok | {:error, term()}
  def delete_own(channel_id, message_id, emoji) do
    emoji = emoji |> resolve_emoji() |> URI.encode()

    case EDA.HTTP.Client.delete(
           "/channels/#{channel_id}/messages/#{message_id}/reactions/#{emoji}/@me"
         ) do
      {:ok, _} -> :ok
      error -> error
    end
  end

  @doc "Removes a user's reaction from a message."
  @spec delete_user(
          String.t() | integer(),
          String.t() | integer(),
          String.t() | EDA.Emoji.t(),
          String.t() | integer()
        ) :: :ok | {:error, term()}
  def delete_user(channel_id, message_id, emoji, user_id) do
    emoji = emoji |> resolve_emoji() |> URI.encode()

    case EDA.HTTP.Client.delete(
           "/channels/#{channel_id}/messages/#{message_id}/reactions/#{emoji}/#{user_id}"
         ) do
      {:ok, _} -> :ok
      error -> error
    end
  end

  @doc "Gets users who reacted with an emoji."
  @spec list(
          String.t() | integer(),
          String.t() | integer(),
          String.t() | EDA.Emoji.t(),
          keyword()
        ) :: {:ok, [map()]} | {:error, term()}
  def list(channel_id, message_id, emoji, opts \\ []) do
    emoji = emoji |> resolve_emoji() |> URI.encode()

    EDA.HTTP.Client.get(
      with_query("/channels/#{channel_id}/messages/#{message_id}/reactions/#{emoji}", opts, [
        :type,
        :after,
        :limit
      ])
    )
  end

  @doc """
  Returns a lazy `Stream` that paginates through all users who reacted with an emoji.

  Uses after-only pagination (Discord constraint for the reactions endpoint).

  ## Options

  - `:per_page` — users per request (1-100, default 100)
  - `:after` — start after this user ID

  ## Examples

      EDA.API.Reaction.stream(channel_id, message_id, "👍") |> Enum.to_list()
      EDA.API.Reaction.stream(channel_id, message_id, "👍", per_page: 50)
      |> Stream.take(10) |> Enum.to_list()
  """
  @spec stream(
          String.t() | integer(),
          String.t() | integer(),
          String.t() | EDA.Emoji.t(),
          keyword()
        ) :: Enumerable.t()
  def stream(channel_id, message_id, emoji, opts \\ []) do
    per_page = Keyword.get(opts, :per_page, 100)
    initial_cursor = opts[:after]

    EDA.Paginator.stream(
      fetch: fn cursor ->
        query = [limit: per_page] ++ if(cursor, do: [after: cursor], else: [])
        list(channel_id, message_id, emoji, query)
      end,
      cursor_key: "id",
      direction: :after,
      per_page: per_page,
      initial_cursor: initial_cursor
    )
  end

  @doc "Removes all reactions from a message."
  @spec delete_all(String.t() | integer(), String.t() | integer()) :: :ok | {:error, term()}
  def delete_all(channel_id, message_id) do
    case EDA.HTTP.Client.delete("/channels/#{channel_id}/messages/#{message_id}/reactions") do
      {:ok, _} -> :ok
      error -> error
    end
  end

  @doc "Removes all reactions of a specific emoji from a message."
  @spec delete_emoji(
          String.t() | integer(),
          String.t() | integer(),
          String.t() | EDA.Emoji.t()
        ) :: :ok | {:error, term()}
  def delete_emoji(channel_id, message_id, emoji) do
    emoji = emoji |> resolve_emoji() |> URI.encode()

    case EDA.HTTP.Client.delete(
           "/channels/#{channel_id}/messages/#{message_id}/reactions/#{emoji}"
         ) do
      {:ok, _} -> :ok
      error -> error
    end
  end
end
