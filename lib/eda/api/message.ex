defmodule EDA.API.Message do
  @moduledoc """
  REST API endpoints for Discord messages.

  All functions return `{:ok, result}` or `{:error, reason}`.
  """

  import EDA.HTTP.Client

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

  @doc "Gets a message by ID."
  @spec get(String.t() | integer(), String.t() | integer()) ::
          {:ok, map()} | {:error, term()}
  def get(channel_id, message_id) do
    EDA.HTTP.Client.get("/channels/#{channel_id}/messages/#{message_id}")
  end

  @doc "Gets messages from a channel."
  @spec list(String.t() | integer(), keyword()) :: {:ok, [map()]} | {:error, term()}
  def list(channel_id, opts \\ []) do
    EDA.HTTP.Client.get(with_query("/channels/#{channel_id}/messages", opts))
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

  @doc "Edits a message."
  @spec edit(String.t() | integer(), String.t() | integer(), map() | keyword()) ::
          {:ok, map()} | {:error, term()}
  def edit(channel_id, message_id, opts) when is_list(opts) do
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

  @doc "Gets pinned messages in a channel."
  @spec pinned(String.t() | integer()) :: {:ok, [map()]} | {:error, term()}
  def pinned(channel_id) do
    EDA.HTTP.Client.get("/channels/#{channel_id}/pins")
  end

  @doc "Pins a message in a channel."
  @spec pin(String.t() | integer(), String.t() | integer()) :: :ok | {:error, term()}
  def pin(channel_id, message_id) do
    case put("/channels/#{channel_id}/pins/#{message_id}", %{}) do
      {:ok, _} -> :ok
      error -> error
    end
  end

  @doc "Unpins a message from a channel."
  @spec unpin(String.t() | integer(), String.t() | integer()) :: :ok | {:error, term()}
  def unpin(channel_id, message_id) do
    case EDA.HTTP.Client.delete("/channels/#{channel_id}/pins/#{message_id}") do
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
