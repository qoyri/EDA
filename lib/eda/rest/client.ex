defmodule EDA.REST.Client do
  @moduledoc """
  HTTP client for Discord REST API.

  Provides functions to interact with Discord's REST API,
  with automatic rate limiting and error handling.

  ## Examples

      # Send a message
      EDA.REST.Client.create_message(channel_id, "Hello, World!")

      # Send a message with an embed
      EDA.REST.Client.create_message(channel_id, %{
        content: "Check this out!",
        embeds: [%{title: "Cool Embed", description: "Very nice"}]
      })

      # Get guild info
      {:ok, guild} = EDA.REST.Client.get_guild(guild_id)
  """

  require Logger

  @base_url "https://discord.com/api/v10"
  @user_agent "DiscordBot (EDA, 0.1.0)"

  # Messages

  @doc """
  Creates a message in a channel.

  ## Parameters

  - `channel_id` - The ID of the channel
  - `content` - Message content (string) or full message payload (map)

  ## Examples

      # Simple text message
      create_message(channel_id, "Hello!")

      # With embed
      create_message(channel_id, %{
        content: "Check this out!",
        embeds: [%{title: "Title", description: "Description"}]
      })
  """
  @spec create_message(String.t() | integer(), String.t() | map()) ::
          {:ok, map()} | {:error, term()}
  def create_message(channel_id, content) when is_binary(content) do
    create_message(channel_id, %{content: content})
  end

  def create_message(channel_id, payload) when is_map(payload) do
    post("/channels/#{channel_id}/messages", payload)
  end

  @doc """
  Edits a message.
  """
  @spec edit_message(String.t() | integer(), String.t() | integer(), map()) ::
          {:ok, map()} | {:error, term()}
  def edit_message(channel_id, message_id, payload) do
    patch("/channels/#{channel_id}/messages/#{message_id}", payload)
  end

  @doc """
  Deletes a message.
  """
  @spec delete_message(String.t() | integer(), String.t() | integer()) ::
          :ok | {:error, term()}
  def delete_message(channel_id, message_id) do
    case delete("/channels/#{channel_id}/messages/#{message_id}") do
      {:ok, _} -> :ok
      error -> error
    end
  end

  # Channels

  @doc """
  Gets a channel by ID.
  """
  @spec get_channel(String.t() | integer()) :: {:ok, map()} | {:error, term()}
  def get_channel(channel_id) do
    get("/channels/#{channel_id}")
  end

  @doc """
  Modifies a channel.
  """
  @spec modify_channel(String.t() | integer(), map()) :: {:ok, map()} | {:error, term()}
  def modify_channel(channel_id, payload) do
    patch("/channels/#{channel_id}", payload)
  end

  # Guilds

  @doc """
  Gets a guild by ID.
  """
  @spec get_guild(String.t() | integer()) :: {:ok, map()} | {:error, term()}
  def get_guild(guild_id) do
    get("/guilds/#{guild_id}")
  end

  @doc """
  Gets channels in a guild.
  """
  @spec get_guild_channels(String.t() | integer()) :: {:ok, [map()]} | {:error, term()}
  def get_guild_channels(guild_id) do
    get("/guilds/#{guild_id}/channels")
  end

  @doc """
  Gets a member of a guild.
  """
  @spec get_guild_member(String.t() | integer(), String.t() | integer()) ::
          {:ok, map()} | {:error, term()}
  def get_guild_member(guild_id, user_id) do
    get("/guilds/#{guild_id}/members/#{user_id}")
  end

  # Users

  @doc """
  Gets the current bot user.
  """
  @spec get_current_user() :: {:ok, map()} | {:error, term()}
  def get_current_user do
    get("/users/@me")
  end

  @doc """
  Gets a user by ID.
  """
  @spec get_user(String.t() | integer()) :: {:ok, map()} | {:error, term()}
  def get_user(user_id) do
    get("/users/#{user_id}")
  end

  # Reactions

  @doc """
  Adds a reaction to a message.
  """
  @spec create_reaction(String.t() | integer(), String.t() | integer(), String.t()) ::
          :ok | {:error, term()}
  def create_reaction(channel_id, message_id, emoji) do
    emoji = URI.encode(emoji)

    case put("/channels/#{channel_id}/messages/#{message_id}/reactions/#{emoji}/@me", %{}) do
      {:ok, _} -> :ok
      error -> error
    end
  end

  # Interactions

  @doc """
  Responds to an interaction.
  """
  @spec create_interaction_response(
          String.t() | integer(),
          String.t(),
          map()
        ) :: :ok | {:error, term()}
  def create_interaction_response(interaction_id, interaction_token, payload) do
    # Interaction responses don't use the normal auth header
    url = "#{@base_url}/interactions/#{interaction_id}/#{interaction_token}/callback"

    case HTTPoison.post(url, Jason.encode!(payload), json_headers()) do
      {:ok, %{status_code: code}} when code in 200..299 -> :ok
      {:ok, response} -> {:error, parse_error(response)}
      {:error, error} -> {:error, error}
    end
  end

  # HTTP Methods

  defp get(path) do
    request(:get, path)
  end

  defp post(path, body) do
    request(:post, path, body)
  end

  defp put(path, body) do
    request(:put, path, body)
  end

  defp patch(path, body) do
    request(:patch, path, body)
  end

  defp delete(path) do
    request(:delete, path)
  end

  defp request(method, path, body \\ nil) do
    url = @base_url <> path
    headers = auth_headers()

    # Use rate limiter
    EDA.REST.RateLimiter.queue(method, path, fn ->
      result =
        case method do
          :get -> HTTPoison.get(url, headers)
          :post -> HTTPoison.post(url, Jason.encode!(body), headers)
          :put -> HTTPoison.put(url, Jason.encode!(body), headers)
          :patch -> HTTPoison.patch(url, Jason.encode!(body), headers)
          :delete -> HTTPoison.delete(url, headers)
        end

      handle_response(result)
    end)
  end

  defp handle_response({:ok, %{status_code: 204}}) do
    {:ok, nil}
  end

  defp handle_response({:ok, %{status_code: code, body: body, headers: headers}})
       when code in 200..299 do
    # Parse rate limit headers for the rate limiter
    parse_rate_limit_headers(headers)

    case Jason.decode(body) do
      {:ok, data} -> {:ok, data}
      {:error, _} -> {:ok, body}
    end
  end

  defp handle_response({:ok, %{status_code: 429, body: body, headers: headers}}) do
    # Rate limited - this shouldn't happen if rate limiter is working
    retry_after = get_retry_after(headers, body)
    Logger.warning("Rate limited! Retry after #{retry_after}ms")
    {:error, {:rate_limited, retry_after}}
  end

  defp handle_response({:ok, response}) do
    {:error, parse_error(response)}
  end

  defp handle_response({:error, error}) do
    {:error, error}
  end

  defp parse_error(%{status_code: code, body: body}) do
    case Jason.decode(body) do
      {:ok, %{"message" => message, "code" => error_code}} ->
        %{status: code, message: message, code: error_code}

      {:ok, data} ->
        %{status: code, data: data}

      {:error, _} ->
        %{status: code, body: body}
    end
  end

  defp get_retry_after(headers, body) do
    # Check header first
    case List.keyfind(headers, "Retry-After", 0) || List.keyfind(headers, "retry-after", 0) do
      {_, value} ->
        String.to_integer(value) * 1000

      nil ->
        # Fall back to body
        case Jason.decode(body) do
          {:ok, %{"retry_after" => seconds}} -> trunc(seconds * 1000)
          _ -> 5000
        end
    end
  end

  defp parse_rate_limit_headers(headers) do
    # Could be used to proactively track rate limits
    _remaining = get_header(headers, "x-ratelimit-remaining")
    _reset_after = get_header(headers, "x-ratelimit-reset-after")
    _bucket = get_header(headers, "x-ratelimit-bucket")
    :ok
  end

  defp get_header(headers, key) do
    case List.keyfind(headers, key, 0) || List.keyfind(headers, String.downcase(key), 0) do
      {_, value} -> value
      nil -> nil
    end
  end

  defp auth_headers do
    [
      {"Authorization", "Bot #{EDA.token()}"},
      {"Content-Type", "application/json"},
      {"User-Agent", @user_agent}
    ]
  end

  defp json_headers do
    [
      {"Content-Type", "application/json"},
      {"User-Agent", @user_agent}
    ]
  end
end
