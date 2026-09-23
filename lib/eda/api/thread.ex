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
    check_options!(body, @from_message_keys, "EDA.API.Thread.start_from_message/3")
    post("/channels/#{channel_id}/messages/#{message_id}/threads", body)
  end

  @doc "Starts a thread without a message."
  @spec start(String.t() | integer(), map() | keyword()) :: {:ok, map()} | {:error, term()}
  def start(channel_id, opts) do
    body = Map.new(opts)
    check_options!(body, @thread_keys, "EDA.API.Thread.start/2")

    post(
      "/channels/#{channel_id}/threads",
      EDA.Enum.encode(body, type: &EDA.Channel.type_value/1)
    )
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
    check_options!(opts, @forum_keys, "EDA.API.Thread.create_post/3")
    check_options!(message_opts, @post_message_keys, "EDA.API.Thread.create_post/3 (message)")
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

  @archived_keys ~w(before limit)a

  @doc """
  Lists a channel's public archived threads, most recently archived first.

  `GET /channels/{channel_id}/threads/archived/public`. Answers
  `%{"threads" => [...], "members" => [...], "has_more" => boolean}` — `members` holds the
  bot's own thread member for each thread it joined. Needs `READ_MESSAGE_HISTORY`.

  ## Options

    * `:before` — threads archived before this time, a `DateTime` or an ISO8601 string
    * `:limit` — how many to return
  """
  @spec list_public_archived(String.t() | integer(), keyword()) :: {:ok, map()} | {:error, term()}
  def list_public_archived(channel_id, opts \\ []) do
    list_archived(
      "/channels/#{channel_id}/threads/archived/public",
      opts,
      "list_public_archived/2"
    )
  end

  @doc """
  Lists a channel's private archived threads, most recently archived first. Needs
  `READ_MESSAGE_HISTORY` and `MANAGE_THREADS`. Same options and answer as
  `list_public_archived/2`.
  """
  @spec list_private_archived(String.t() | integer(), keyword()) ::
          {:ok, map()} | {:error, term()}
  def list_private_archived(channel_id, opts \\ []) do
    list_archived(
      "/channels/#{channel_id}/threads/archived/private",
      opts,
      "list_private_archived/2"
    )
  end

  @doc """
  Lists the private archived threads of a channel that the bot has joined, newest id first.
  Needs `READ_MESSAGE_HISTORY`.

  Same answer as `list_public_archived/2`, but `:before` is a **thread id** here, not a time.
  """
  @spec list_joined_private_archived(String.t() | integer(), keyword()) ::
          {:ok, map()} | {:error, term()}
  def list_joined_private_archived(channel_id, opts \\ []) do
    check_options!(opts, @archived_keys, "EDA.API.Thread.list_joined_private_archived/2")

    EDA.HTTP.Client.get(
      with_query("/channels/#{channel_id}/users/@me/threads/archived/private", opts)
    )
  end

  @doc """
  Streams a channel's archived threads, lazily, page after page.

  `kind` is `:public`, `:private` or `:joined_private`. Pages follow Discord's own cursor for
  each kind — the archive time, or the thread id for joined private threads.

      EDA.API.Thread.stream_archived(channel_id, :public) |> Enum.take(250)
  """
  @spec stream_archived(String.t() | integer(), :public | :private | :joined_private, keyword()) ::
          Enumerable.t()
  def stream_archived(channel_id, kind, opts \\ [])
      when kind in [:public, :private, :joined_private] do
    check_options!(opts, [:per_page], "EDA.API.Thread.stream_archived/3")
    per_page = Keyword.get(opts, :per_page, 100)

    {fetch, cursor_key} =
      case kind do
        :public -> {&list_public_archived/2, &archive_timestamp/1}
        :private -> {&list_private_archived/2, &archive_timestamp/1}
        :joined_private -> {&list_joined_private_archived/2, "id"}
      end

    EDA.Paginator.stream(
      fetch: fn cursor ->
        query = [limit: per_page] ++ if(cursor, do: [before: cursor], else: [])

        with {:ok, %{"threads" => threads}} <- fetch.(channel_id, query), do: {:ok, threads}
      end,
      cursor_key: cursor_key,
      direction: :before,
      per_page: per_page
    )
  end

  defp list_archived(path, opts, function) do
    check_options!(opts, @archived_keys, "EDA.API.Thread." <> function)

    opts =
      case opts[:before] do
        %DateTime{} = before -> Keyword.put(opts, :before, DateTime.to_iso8601(before))
        _ -> opts
      end

    EDA.HTTP.Client.get(with_query(path, opts))
  end

  defp archive_timestamp(thread), do: get_in(thread, ["thread_metadata", "archive_timestamp"])
end
