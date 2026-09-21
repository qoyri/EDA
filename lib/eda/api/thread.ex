defmodule EDA.API.Thread do
  @moduledoc """
  REST API endpoints for Discord threads.

  All functions return `{:ok, result}` or `{:error, reason}`.
  """

  import EDA.HTTP.Client

  # From Discord's published request types.
  @from_message_keys ~w(name auto_archive_duration rate_limit_per_user)a
  @thread_keys ~w(name auto_archive_duration rate_limit_per_user type invitable)a
  @forum_keys ~w(name auto_archive_duration rate_limit_per_user applied_tags)a

  # A forum post's starter message takes the full message body, plus the keys EDA's
  # payload builder interprets.
  @post_message_keys ~w(content nonce tts embeds allowed_mentions message_reference
                        components sticker_ids attachments flags enforce_nonce poll
                        shared_client_theme embed file files v2)a

  @doc "Starts a thread from an existing message."
  @spec start_from_message(String.t() | integer(), String.t() | integer(), map() | keyword()) ::
          {:ok, map()} | {:error, term()}
  def start_from_message(channel_id, message_id, opts) do
    body = Map.new(opts)
    check_options(body, @from_message_keys, "EDA.API.Thread.start_from_message/3")
    post("/channels/#{channel_id}/messages/#{message_id}/threads", body)
  end

  @doc "Starts a thread without a message."
  @spec start(String.t() | integer(), map() | keyword()) :: {:ok, map()} | {:error, term()}
  def start(channel_id, opts) do
    body = Map.new(opts)
    check_options(body, @thread_keys, "EDA.API.Thread.start/2")
    post("/channels/#{channel_id}/threads", body)
  end

  @doc """
  Creates a new forum/media channel post (thread with a starter message).

  Discord's `POST /channels/{channel_id}/threads` for forum channels requires
  a `message` object in the body. At least one of `:content`, `:embeds`,
  `:sticker_ids`, or `:files` must be provided in `message_opts`.

  ## Parameters

    * `channel_id` — the forum or media channel ID
    * `opts` — thread options:
      * `:name` (required) — thread name (1–100 characters)
      * `:auto_archive_duration` — minutes before auto-archive (60, 1440, 4320, 10080)
      * `:rate_limit_per_user` — slowmode in seconds (0–21600)
      * `:applied_tags` — list of tag ID strings to apply (max 5)
    * `message_opts` — starter message content:
      * `:content` — text content
      * `:embeds` — list of embeds
      * `:embed` — single embed (convenience, cannot combine with `:embeds`)
      * `:components` — message components
      * `:sticker_ids` — list of sticker IDs
      * `:files` — list of files (enables multipart upload)
      * `:file` — single file (convenience, cannot combine with `:files`)
      * `:allowed_mentions` — allowed mentions object

  ## Examples

      # Simple text post
      Thread.create_post("forum_id", [name: "Help needed"], content: "How do I…?")

      # Post with tags and an embed
      Thread.create_post("forum_id",
        [name: "Bug Report", applied_tags: ["tag1", "tag2"]],
        content: "Found a bug", embeds: [%{title: "Details"}]
      )

      # Post with file attachment
      Thread.create_post("forum_id",
        [name: "Screenshot"],
        content: "See attached", file: "path/to/image.png"
      )
  """
  @spec create_post(String.t() | integer(), keyword(), keyword()) ::
          {:ok, map()} | {:error, term()}
  def create_post(channel_id, opts, message_opts \\ []) do
    check_options(opts, @forum_keys, "EDA.API.Thread.create_post/3")
    check_options(message_opts, @post_message_keys, "EDA.API.Thread.create_post/3 (message)")
    path = "/channels/#{channel_id}/threads"

    case build_message_payload(message_opts) do
      {message_payload, files} ->
        body = build_forum_body(opts, message_payload)
        request_multipart(:post, path, body, files)

      message_payload ->
        body = build_forum_body(opts, message_payload)
        post(path, body)
    end
  end

  defp build_forum_body(opts, message_payload) do
    body = %{name: Keyword.fetch!(opts, :name), message: message_payload}

    body =
      case Keyword.get(opts, :auto_archive_duration) do
        nil -> body
        val -> Map.put(body, :auto_archive_duration, val)
      end

    body =
      case Keyword.get(opts, :rate_limit_per_user) do
        nil -> body
        val -> Map.put(body, :rate_limit_per_user, val)
      end

    case Keyword.get(opts, :applied_tags) do
      nil -> body
      val -> Map.put(body, :applied_tags, val)
    end
  end

  @doc "Joins a thread."
  @spec join(String.t() | integer()) :: :ok | {:error, term()}
  def join(channel_id) do
    case put("/channels/#{channel_id}/thread-members/@me", %{}) do
      {:ok, _} -> :ok
      error -> error
    end
  end

  @doc "Leaves a thread."
  @spec leave(String.t() | integer()) :: :ok | {:error, term()}
  def leave(channel_id) do
    case EDA.HTTP.Client.delete("/channels/#{channel_id}/thread-members/@me") do
      {:ok, _} -> :ok
      error -> error
    end
  end

  @doc "Adds a member to a thread."
  @spec add_member(String.t() | integer(), String.t() | integer()) :: :ok | {:error, term()}
  def add_member(channel_id, user_id) do
    case put("/channels/#{channel_id}/thread-members/#{user_id}", %{}) do
      {:ok, _} -> :ok
      error -> error
    end
  end

  @doc """
  Removes a member from a thread.

  ## Examples

      :ok = Thread.remove_member(thread_id, user_id)
  """
  @spec remove_member(String.t() | integer(), String.t() | integer()) :: :ok | {:error, term()}
  def remove_member(channel_id, user_id) do
    case EDA.HTTP.Client.delete("/channels/#{channel_id}/thread-members/#{user_id}") do
      {:ok, _} -> :ok
      error -> error
    end
  end

  @doc """
  Gets a thread member object for a user.

  ## Examples

      {:ok, member} = Thread.get_member(thread_id, user_id)
  """
  @spec get_member(String.t() | integer(), String.t() | integer()) ::
          {:ok, map()} | {:error, term()}
  def get_member(channel_id, user_id) do
    EDA.HTTP.Client.get("/channels/#{channel_id}/thread-members/#{user_id}")
  end

  @doc """
  Lists members of a thread.

  ## Examples

      {:ok, members} = Thread.list_members(thread_id)
  """
  @spec list_members(String.t() | integer()) :: {:ok, [map()]} | {:error, term()}
  def list_members(channel_id) do
    EDA.HTTP.Client.get("/channels/#{channel_id}/thread-members")
  end

  @doc "Lists active threads in a guild."
  @spec list_active(String.t() | integer()) :: {:ok, map()} | {:error, term()}
  def list_active(guild_id) do
    EDA.HTTP.Client.get("/guilds/#{guild_id}/threads/active")
  end
end
