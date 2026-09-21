defmodule EDA.API.Message do
  @moduledoc """
  REST API endpoints for Discord messages.

  All functions return `{:ok, result}` or `{:error, reason}`.
  """

  import EDA.HTTP.Client

  # Discord's body for each route, plus the keys EDA itself interprets: `embed` and `v2` are
  # rewritten by the payload builder, `file`/`files` become multipart parts, and
  # `delete_after` schedules a deletion. From Discord's published request types.
  @create_keys ~w(content nonce tts embeds allowed_mentions message_reference components
                  sticker_ids attachments flags enforce_nonce poll shared_client_theme
                  embed file files v2 delete_after)a

  @edit_keys ~w(content embeds flags allowed_mentions attachments components
                embed file files v2)a

  @doc """
  Creates a message in a channel.

  ## Parameters

  - `channel_id` - The ID of the channel
  - `content` - Message content (string), full message payload (map), or keyword options

  ## Examples

      EDA.API.Message.create(channel_id, "Hello!")
      EDA.API.Message.create(channel_id, content: "Look!", embeds: [embed])
      EDA.API.Message.create(channel_id, content: "File!", files: [file])
  """
  @spec create(String.t() | integer(), String.t() | map() | keyword()) ::
          {:ok, map()} | {:error, term()}
  def create(channel_id, content) when is_binary(content) do
    create(channel_id, %{content: content})
  end

  def create(channel_id, opts) when is_list(opts) do
    check_options!(opts, @create_keys, "EDA.API.Message.create/2")
    {delete_after, opts} = Keyword.pop(opts, :delete_after)

    result =
      case build_message_payload(opts) do
        {payload, files} ->
          request_multipart(:post, "/channels/#{channel_id}/messages", payload, files)

        payload ->
          post("/channels/#{channel_id}/messages", payload)
      end

    maybe_schedule_delete(result, channel_id, delete_after)
  end

  def create(channel_id, payload) when is_map(payload) do
    {delete_after, payload} = Map.pop(payload, :delete_after)
    result = post("/channels/#{channel_id}/messages", payload)
    maybe_schedule_delete(result, channel_id, delete_after)
  end

  @doc """
  Forwards a message to another channel.

  Creates a message reference with `type: 1` (forward) pointing to the original message.

  ## The bot must be able to read the message it forwards

  Forwarding is not a way to relay a message out of a channel the bot cannot see. Discord
  checks read access to the **source** message's content at forward time and rejects the
  request with code `160014` otherwise — typically a missing `view_channel` or
  `read_message_history` in the source channel, or a source channel the bot is no longer in:

      case EDA.API.Message.forward(target_id, source_id, message_id) do
        {:ok, message} -> message
        {:error, %{code: 160_014}} -> :cannot_read_source
      end

  `EDA.Error.cannot_forward_unreadable_message/0` names that code.

  ## Examples

      EDA.API.Message.forward(target_channel_id, source_channel_id, message_id)
  """
  @spec forward(String.t() | integer(), String.t() | integer(), String.t() | integer()) ::
          {:ok, map()} | {:error, term()}
  def forward(target_channel_id, source_channel_id, message_id) do
    post("/channels/#{target_channel_id}/messages", %{
      message_reference: %{
        type: 1,
        channel_id: to_string(source_channel_id),
        message_id: to_string(message_id)
      }
    })
  end

  @doc """
  Publishes a message in an announcement channel to every channel following it.

  `POST /channels/{channel_id}/messages/{message_id}/crosspost`. Needs `SEND_MESSAGES` for the
  bot's own message, and `MANAGE_MESSAGES` as well for anyone else's. A message is published
  once; publishing it again fails with `40033` (`EDA.Error.message_already_crossposted/0`).
  """
  @spec crosspost(String.t() | integer(), String.t() | integer()) ::
          {:ok, map()} | {:error, term()}
  def crosspost(channel_id, message_id) do
    post("/channels/#{channel_id}/messages/#{message_id}/crosspost", %{})
  end

  @doc """
  Searches a guild's message history.

  `GET /guilds/{guild_id}/messages/search`. Requires `READ_MESSAGE_HISTORY` in the channels
  searched, and is gated on the **`MESSAGE_CONTENT`** privileged intent.

  Returns Discord's raw payload. `EDA.Message.search/2` returns parsed structs and flattens
  the nesting described below.

  ## The `messages` key is a list of *lists*

  Each entry is a context group, not a message: Discord returns the matching message
  surrounded by its neighbours, and marks the match itself with `"hit" => true`. A group of
  one is the usual case, but nothing promises it.

      {:ok, %{"messages" => groups, "total_results" => total}} =
        EDA.API.Message.search(guild_id, content: "deploy")

      hits = Enum.map(groups, fn group -> Enum.find(group, & &1["hit"]) end)

  ## Options

  Multi-valued filters take a list and become repeated query keys.

    * `:content` - free text, max 1024 characters
    * `:channel_id` - restrict to these channels, max 500
    * `:author_id` - max 100 · `:author_type` - `:user`, `:bot` or `:webhook`
    * `:mentions` - messages mentioning these users, max 100
    * `:mentions_role_id` - max 100 · `:mention_everyone` - boolean
    * `:replied_to_user_id`, `:replied_to_message_id` - max 100
    * `:has` - `:image`, `:sound`, `:video`, `:file`, `:sticker`, `:embed`, `:link`,
      `:poll` or `:snapshot`
    * `:embed_type`, `:embed_provider`, `:link_hostname`, `:attachment_filename`,
      `:attachment_extension` - max 100 each
    * `:pinned` - boolean · `:include_nsfw` - boolean, default `false`
    * `:min_id` / `:max_id` - snowflake bounds
    * `:sort_by` - `:timestamp` (default) or `:relevance` · `:sort_order` - `:desc` or `:asc`
    * `:limit` - 1–25, default 25 · `:offset` - max 9975
    * `:slop` - words allowed between matching tokens, max 100, default 2

  ## Examples

      EDA.API.Message.search(guild_id,
        content: "incident",
        channel_id: [ops_channel, alerts_channel],
        has: [:link],
        sort_by: :relevance,
        limit: 10
      )

  An option this endpoint does not define is **refused**, not forwarded: Discord ignores a
  query parameter it does not recognise, so `contnet:` would quietly return the guild's whole
  history while looking like a filtered search.

  ## Caveats Discord documents

    * **Sort order is ignored when sorting by relevance.**
    * `total_results` is approximate while messages are being created or deleted, and a page
      may come back slightly shorter than `:limit`.
    * `:offset` caps at 9975, so at most ten thousand results are reachable — narrow the
      query rather than paging to the end.
    * A guild whose history is still being indexed answers **HTTP 202** rather than results.
      That is a success status carrying no messages, so it is reported as
      `{:error, {:index_pending, retry_after_seconds}}` instead of an empty search.
  """
  @spec search(String.t() | integer(), keyword()) :: {:ok, map()} | {:error, term()}
  def search(guild_id, opts \\ []) do
    query = opts |> validate_search!() |> normalize_search()

    case EDA.HTTP.Client.get(with_query("/guilds/#{guild_id}/messages/search", query)) do
      {:ok, %{"code" => 110_000} = body} ->
        {:error, {:index_pending, body["retry_after"]}}

      other ->
        other
    end
  end

  @search_limits %{
    channel_id: 500,
    author_id: 100,
    mentions: 100,
    mentions_role_id: 100,
    replied_to_user_id: 100,
    replied_to_message_id: 100,
    embed_type: 100,
    embed_provider: 100,
    link_hostname: 100,
    attachment_filename: 100,
    attachment_extension: 100
  }

  @has_values ~w(image sound video file sticker embed link poll snapshot)a
  @author_types ~w(user bot webhook)a
  @sort_by ~w(timestamp relevance)a
  @sort_order ~w(asc desc)a

  @search_keys ~w(content channel_id author_id author_type mentions mentions_role_id
                  mention_everyone replied_to_user_id replied_to_message_id pinned has
                  embed_type embed_provider link_hostname attachment_filename
                  attachment_extension sort_by sort_order limit offset slop min_id max_id
                  include_nsfw)a

  # Discord answers an over-long filter with an opaque 50035, so the limits it documents are
  # checked here where the message can name the option.
  #
  # An unknown key is refused rather than forwarded: Discord ignores a query parameter it
  # does not recognise, so `contnet:` would return the whole guild's history while looking
  # like a filtered search. That is the one failure mode a search must not have.
  defp validate_search!(opts) do
    check_options!(opts, @search_keys, "EDA.API.Message.search/2")
    Enum.each(opts, fn {key, value} -> validate_search_opt!(key, value) end)
    opts
  end

  defp validate_search_opt!(:limit, value) when value not in 1..25 do
    raise ArgumentError, ":limit must be between 1 and 25, got: #{inspect(value)}"
  end

  defp validate_search_opt!(:offset, value) when is_integer(value) and value > 9975 do
    raise ArgumentError, ":offset caps at 9975, got: #{inspect(value)}"
  end

  defp validate_search_opt!(:slop, value) when is_integer(value) and value > 100 do
    raise ArgumentError, ":slop caps at 100, got: #{inspect(value)}"
  end

  defp validate_search_opt!(:content, value) when is_binary(value) do
    if String.length(value) > 1024 do
      raise ArgumentError, ":content is limited to 1024 characters"
    end
  end

  defp validate_search_opt!(:has, value), do: validate_members!(:has, value, @has_values)

  defp validate_search_opt!(:author_type, value),
    do: validate_members!(:author_type, value, @author_types)

  defp validate_search_opt!(:sort_by, value), do: validate_member!(:sort_by, value, @sort_by)

  defp validate_search_opt!(:sort_order, value),
    do: validate_member!(:sort_order, value, @sort_order)

  defp validate_search_opt!(key, value) when is_list(value) do
    case Map.get(@search_limits, key) do
      nil ->
        :ok

      max when length(value) > max ->
        raise ArgumentError,
              "#{inspect(key)} accepts at most #{max} values, got #{length(value)}"

      _max ->
        :ok
    end
  end

  defp validate_search_opt!(_key, _value), do: :ok

  defp validate_members!(key, values, allowed) when is_list(values) do
    Enum.each(values, &validate_member!(key, &1, allowed))
  end

  defp validate_members!(key, value, allowed), do: validate_member!(key, value, allowed)

  defp validate_member!(key, value, allowed) do
    normalized = if is_binary(value), do: String.to_existing_atom(value), else: value

    unless normalized in allowed do
      raise ArgumentError, "#{inspect(key)} accepts #{inspect(allowed)}, got: #{inspect(value)}"
    end
  rescue
    ArgumentError ->
      reraise ArgumentError,
              [message: "#{inspect(key)} accepts #{inspect(allowed)}, got: #{inspect(value)}"],
              __STACKTRACE__
  end

  # Atoms are friendlier to write than Discord's strings, and ids may be integers.
  defp normalize_search(opts) do
    Enum.map(opts, fn
      {key, values} when is_list(values) -> {key, Enum.map(values, &to_query_value/1)}
      {key, value} -> {key, to_query_value(value)}
    end)
  end

  defp to_query_value(value) when is_atom(value) and not is_boolean(value) and not is_nil(value),
    do: Atom.to_string(value)

  defp to_query_value(value) when is_integer(value), do: Integer.to_string(value)
  defp to_query_value(value), do: value

  @doc "Gets a message by ID."
  @spec get(String.t() | integer(), String.t() | integer()) ::
          {:ok, map()} | {:error, term()}
  def get(channel_id, message_id) do
    EDA.HTTP.Client.get("/channels/#{channel_id}/messages/#{message_id}")
  end

  @doc "Gets messages from a channel."
  @spec list(String.t() | integer(), keyword()) :: {:ok, [map()]} | {:error, term()}
  def list(channel_id, opts \\ []) do
    EDA.HTTP.Client.get(
      with_query("/channels/#{channel_id}/messages", opts, [:around, :before, :after, :limit])
    )
  end

  @doc "Bulk deletes messages (2-100, not older than 14 days)."
  @spec bulk_delete(String.t() | integer(), [String.t() | integer()]) ::
          :ok | {:error, term()}
  def bulk_delete(channel_id, message_ids) do
    case post("/channels/#{channel_id}/messages/bulk-delete", %{messages: message_ids}) do
      {:ok, _} -> :ok
      error -> error
    end
  end

  @doc """
  Edits a message.

  Accepts a keyword list of options (which may upload files) or a raw payload map.

  ## The `attachments` array replaces, it does not merge

  Discord treats `attachments` as the complete list the message should end up with, so an
  attachment left out of it is deleted. Uploading a file without naming the existing ones
  therefore removes them:

      # keeps only the newly uploaded file — the message's other attachments are gone
      EDA.API.Message.edit(channel_id, message_id, files: [EDA.File.from_path("new.png")])

  Name them with `EDA.Attachment.keep/2` to hold on to them, and the upload is appended:

      EDA.API.Message.edit(channel_id, message_id,
        attachments: Enum.map(message.attachments, &EDA.Attachment.keep/1),
        files: [EDA.File.from_path("new.png")]
      )

  `:attachments` also takes bare ids and raw attachment maps. `EDA.Message.edit/2` has the
  shorter `attachments: :keep` for a message struct you already hold.

  Omitting `:attachments` entirely leaves the message's attachments untouched — it is only
  sending the array that is destructive.

  ## Changing an existing attachment

  `EDA.Attachment.keep/2` carries the two fields Discord lets an edit update, so a spoiler
  can be applied after the fact without re-uploading the file:

      EDA.API.Message.edit(channel_id, message_id,
        attachments: [EDA.Attachment.keep(attachment, is_spoiler: true, description: "Ending")]
      )
  """
  @spec edit(String.t() | integer(), String.t() | integer(), map() | keyword()) ::
          {:ok, map()} | {:error, term()}
  def edit(channel_id, message_id, opts) when is_list(opts) do
    check_options!(opts, @edit_keys, "EDA.API.Message.edit/3")

    case build_message_payload(opts) do
      {payload, files} ->
        request_multipart(
          :patch,
          "/channels/#{channel_id}/messages/#{message_id}",
          payload,
          files
        )

      payload ->
        patch("/channels/#{channel_id}/messages/#{message_id}", payload)
    end
  end

  def edit(channel_id, message_id, payload, opts \\ []) when is_map(payload) do
    patch("/channels/#{channel_id}/messages/#{message_id}", payload, opts)
  end

  @doc "Deletes a message."
  @spec delete(String.t() | integer(), String.t() | integer(), keyword()) ::
          :ok | {:error, term()}
  def delete(channel_id, message_id, opts \\ []) do
    case EDA.HTTP.Client.delete("/channels/#{channel_id}/messages/#{message_id}", opts) do
      {:ok, _} -> :ok
      error -> error
    end
  end

  # ── Pins ──

  @doc """
  Gets one page of a channel's pins.

  Returns Discord's raw envelope: `%{"items" => [pin], "has_more" => boolean}`,
  where each pin is `%{"pinned_at" => iso8601, "message" => message}`.

  ## Options

  - `:before` - ISO8601 timestamp, get pins pinned before this (use the
    `pinned_at` of the last item of the previous page)
  - `:limit` - pins per page (1-50, default 50)
  """
  @spec pins(String.t() | integer(), keyword()) :: {:ok, map()} | {:error, term()}
  def pins(channel_id, opts \\ []) do
    EDA.HTTP.Client.get(
      with_query("/channels/#{channel_id}/messages/pins", opts, [:before, :limit])
    )
  end

  @doc """
  Gets pinned messages in a channel, paginating automatically.

  Returns message objects. Use `pins/2` if you need the `pinned_at` timestamps
  or want to drive the pagination yourself.

  ## Options

  - `:limit` - maximum number of messages to return (default `:infinity`)

  ## Examples

      {:ok, msgs} = EDA.API.Message.pinned(channel_id)
      {:ok, msgs} = EDA.API.Message.pinned(channel_id, limit: 10)
  """
  @spec pinned(String.t() | integer(), keyword()) :: {:ok, [map()]} | {:error, term()}
  def pinned(channel_id, opts \\ []) do
    case Keyword.get(opts, :limit, :infinity) do
      limit when is_integer(limit) and limit <= 0 -> {:ok, []}
      limit -> fetch_pin_pages(channel_id, limit, [], nil)
    end
  end

  defp fetch_pin_pages(channel_id, remaining, acc, cursor) do
    query = [limit: pin_page_size(remaining)] ++ if cursor, do: [before: cursor], else: []

    case pins(channel_id, query) do
      {:ok, %{"items" => []}} ->
        {:ok, acc}

      {:ok, %{"items" => items} = page} ->
        continue_pin_pages(channel_id, remaining, acc, items, page["has_more"])

      {:ok, _unexpected} ->
        {:ok, acc}

      error ->
        if acc == [], do: error, else: {:ok, acc}
    end
  end

  defp pin_page_size(:infinity), do: 50
  defp pin_page_size(remaining), do: min(remaining, 50)

  defp continue_pin_pages(channel_id, remaining, acc, items, has_more) do
    acc = acc ++ Enum.map(items, & &1["message"])
    remaining = if remaining == :infinity, do: :infinity, else: remaining - length(items)

    if has_more != true or remaining == 0 do
      {:ok, acc}
    else
      fetch_pin_pages(channel_id, remaining, acc, List.last(items)["pinned_at"])
    end
  end

  @doc """
  Pins a message in a channel.

  ## Options

  - `:reason` - Audit log reason
  """
  @spec pin(String.t() | integer(), String.t() | integer(), keyword()) :: :ok | {:error, term()}
  def pin(channel_id, message_id, opts \\ []) do
    case put("/channels/#{channel_id}/messages/pins/#{message_id}", %{}, opts) do
      {:ok, _} -> :ok
      error -> error
    end
  end

  @doc """
  Unpins a message from a channel.

  ## Options

  - `:reason` - Audit log reason
  """
  @spec unpin(String.t() | integer(), String.t() | integer(), keyword()) :: :ok | {:error, term()}
  def unpin(channel_id, message_id, opts \\ []) do
    case EDA.HTTP.Client.delete("/channels/#{channel_id}/messages/pins/#{message_id}", opts) do
      {:ok, _} -> :ok
      error -> error
    end
  end

  # ── History (auto-pagination) ──

  @doc """
  Retrieves message history from a channel with automatic pagination.

  Handles Discord's 100-message-per-request limit transparently.
  Supports `:infinity` to retrieve all messages.

  ## Options

  - `:before` - snowflake ID, get messages before this
  - `:after` - snowflake ID, get messages after this
  - `:around` - snowflake ID, get messages around this (single page, max 100)

  ## Examples

      {:ok, msgs} = EDA.API.Message.history(channel_id, 250)
      {:ok, msgs} = EDA.API.Message.history(channel_id, 500, before: msg_id)
      {:ok, msgs} = EDA.API.Message.history(channel_id, :infinity)
  """
  @spec history(String.t() | integer(), pos_integer() | :infinity, keyword()) ::
          {:ok, [map()]} | {:error, term()}
  def history(channel_id, limit, opts \\ []) do
    if opts[:around] do
      list(channel_id, Keyword.put(opts, :limit, min(limit, 100)))
    else
      cursor =
        cond do
          opts[:before] -> [before: opts[:before]]
          opts[:after] -> [after: opts[:after]]
          true -> []
        end

      fetch_pages(channel_id, limit, [], cursor)
    end
  end

  defp fetch_pages(channel_id, remaining, acc, cursor) do
    batch_size = if remaining == :infinity, do: 100, else: min(remaining, 100)
    query = [limit: batch_size] ++ cursor

    case list(channel_id, query) do
      {:ok, []} ->
        {:ok, acc}

      {:ok, messages} ->
        new_acc = acc ++ messages

        new_remaining =
          if remaining == :infinity, do: :infinity, else: remaining - length(messages)

        if length(messages) < batch_size or new_remaining == 0 do
          {:ok, new_acc}
        else
          last_id = List.last(messages)["id"]
          fetch_pages(channel_id, new_remaining, new_acc, before: last_id)
        end

      error ->
        if acc == [], do: error, else: {:ok, acc}
    end
  end

  @doc """
  Returns a lazy `Stream` that yields messages from a channel, page by page.

  ## Options

  - `:before` - start before this message ID
  - `:after` - start after this message ID
  - `:per_page` - messages per request (1-100, default 100)

  ## Examples

      EDA.API.Message.stream(channel_id) |> Stream.take(50) |> Enum.to_list()
      EDA.API.Message.stream(channel_id) |> Enum.find(&(&1["author"]["id"] == user_id))
  """
  @spec stream(String.t() | integer(), keyword()) :: Enumerable.t()
  def stream(channel_id, opts \\ []) do
    per_page = Keyword.get(opts, :per_page, 100)
    direction = if opts[:after], do: :after, else: :before
    initial_cursor = opts[:before] || opts[:after]

    EDA.Paginator.stream(
      fetch: fn cursor ->
        query = [limit: per_page] ++ if(cursor, do: [{direction, cursor}], else: [])
        list(channel_id, query)
      end,
      cursor_key: "id",
      direction: direction,
      per_page: per_page,
      initial_cursor: initial_cursor
    )
  end

  @doc """
  Purges messages from a channel with automatic chunking and 14-day filtering.

  ## Options

  - `:limit` - max messages to purge (default 100, max `:infinity`)
  - `:before` - purge messages before this ID
  - `:after` - purge messages after this ID
  - `:filter` - predicate `fn(message) -> boolean` to select which messages to purge
  - `:filter_old` - filter out messages older than 14 days (default `true`)

  ## Examples

      {:ok, count} = EDA.API.Message.purge(channel_id, limit: 200)
      {:ok, count} = EDA.API.Message.purge(channel_id,
        limit: 500,
        filter: fn msg -> msg["author"]["id"] == user_id end
      )
  """
  @spec purge(String.t() | integer(), keyword()) ::
          {:ok, non_neg_integer()} | {:error, term()}
  def purge(channel_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 100)
    filter_fn = Keyword.get(opts, :filter, fn _ -> true end)
    filter_old = Keyword.get(opts, :filter_old, true)

    with {:ok, messages} <-
           history(channel_id, limit, Keyword.take(opts, [:before, :after])) do
      ids =
        messages
        |> Enum.filter(filter_fn)
        |> maybe_filter_old(filter_old)
        |> Enum.map(& &1["id"])

      do_bulk_delete(channel_id, ids)
    end
  end

  defp maybe_filter_old(messages, false), do: messages

  defp maybe_filter_old(messages, true) do
    fourteen_days_ago = DateTime.add(DateTime.utc_now(), -14, :day)
    cutoff_snowflake = EDA.Snowflake.from_datetime(fourteen_days_ago)

    Enum.filter(messages, fn msg ->
      snowflake =
        case msg["id"] do
          id when is_integer(id) -> id
          id when is_binary(id) -> String.to_integer(id)
        end

      snowflake > cutoff_snowflake
    end)
  end

  defp do_bulk_delete(_channel_id, []), do: {:ok, 0}

  defp do_bulk_delete(channel_id, ids) do
    ids
    |> Enum.chunk_every(100)
    |> Enum.reduce_while({:ok, 0}, fn chunk, {:ok, count} ->
      case bulk_delete(channel_id, chunk) do
        :ok -> {:cont, {:ok, count + length(chunk)}}
        error -> {:halt, error}
      end
    end)
  end

  # ── Reply ──────────────────────────────────────────────────────────

  @doc """
  Replies to a message, automatically setting `message_reference`.

  Accepts a message struct (with `:channel_id` and `:id`) or a raw map
  (with `"channel_id"` and `"id"`).

  ## Examples

      EDA.API.Message.reply(msg, "Got it!")
      EDA.API.Message.reply(msg, content: "Reply with embed", embeds: [embed])
  """
  @spec reply(map(), String.t() | keyword() | map()) :: {:ok, map()} | {:error, term()}
  def reply(%{channel_id: cid, id: mid}, content) do
    do_reply(cid, mid, content)
  end

  def reply(%{"channel_id" => cid, "id" => mid}, content) do
    do_reply(cid, mid, content)
  end

  defp do_reply(channel_id, message_id, content) when is_binary(content) do
    create(channel_id, %{content: content, message_reference: %{message_id: message_id}})
  end

  defp do_reply(channel_id, message_id, opts) when is_list(opts) do
    check_options!(opts, @create_keys, "EDA.API.Message.reply/2")
    {delete_after, opts} = Keyword.pop(opts, :delete_after)

    payload =
      opts
      |> build_message_payload()
      |> then(fn
        {payload, files} ->
          {Map.put(payload, :message_reference, %{message_id: message_id}), files}

        payload ->
          Map.put(payload, :message_reference, %{message_id: message_id})
      end)

    result =
      case payload do
        {payload, files} ->
          request_multipart(:post, "/channels/#{channel_id}/messages", payload, files)

        payload ->
          post("/channels/#{channel_id}/messages", payload)
      end

    maybe_schedule_delete(result, channel_id, delete_after)
  end

  defp do_reply(channel_id, message_id, payload) when is_map(payload) do
    payload = Map.put_new(payload, :message_reference, %{message_id: message_id})
    create(channel_id, payload)
  end

  # ── Private ────────────────────────────────────────────────────────

  defp maybe_schedule_delete({:ok, %{"id" => msg_id}} = result, channel_id, delete_after)
       when is_integer(delete_after) do
    EDA.AutoDelete.schedule(to_string(channel_id), msg_id, delete_after)
    result
  end

  defp maybe_schedule_delete(result, _channel_id, _delete_after), do: result
end
