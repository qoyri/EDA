defmodule EDA.API.Webhook do
  @moduledoc """
  REST API endpoints for Discord webhooks.

  All functions return `{:ok, result}` or `{:error, reason}`.
  """

  import EDA.HTTP.Client

  # From Discord's published request types. The query keys are split out because they
  # travel in the URL, not the body — left in the body they would be ignored, and a message
  # meant for a thread would land in the parent channel.
  @create_keys ~w(name avatar)a
  @modify_keys ~w(name avatar channel_id)a

  @execute_body ~w(content username avatar_url tts embeds allowed_mentions components
                   attachments flags thread_name applied_tags poll)a
  @execute_query ~w(wait thread_id with_components)a

  @edit_body ~w(content embeds flags allowed_mentions components attachments poll)a
  @edit_query ~w(thread_id with_components)a

  # Interpreted by EDA's payload builder rather than sent as-is.
  @builder_keys ~w(embed file files v2)a

  @doc "Creates a webhook for a channel."
  @spec create(String.t() | integer(), map() | keyword()) :: {:ok, map()} | {:error, term()}
  def create(channel_id, opts) do
    body = Map.new(opts)
    check_options!(body, @create_keys, "EDA.API.Webhook.create/2")
    post("/channels/#{channel_id}/webhooks", body)
  end

  @doc "Gets webhooks for a channel."
  @spec list_channel(String.t() | integer()) :: {:ok, [map()]} | {:error, term()}
  def list_channel(channel_id) do
    EDA.HTTP.Client.get("/channels/#{channel_id}/webhooks")
  end

  @doc "Gets webhooks for a guild."
  @spec list_guild(String.t() | integer()) :: {:ok, [map()]} | {:error, term()}
  def list_guild(guild_id) do
    EDA.HTTP.Client.get("/guilds/#{guild_id}/webhooks")
  end

  @doc "Gets a webhook by ID."
  @spec get(String.t() | integer()) :: {:ok, map()} | {:error, term()}
  def get(webhook_id) do
    EDA.HTTP.Client.get("/webhooks/#{webhook_id}")
  end

  @doc "Modifies a webhook."
  @spec modify(String.t() | integer(), map() | keyword()) :: {:ok, map()} | {:error, term()}
  def modify(webhook_id, opts) do
    body = Map.new(opts)
    check_options!(body, @modify_keys, "EDA.API.Webhook.modify/2")
    patch("/webhooks/#{webhook_id}", body)
  end

  @doc "Deletes a webhook."
  @spec delete(String.t() | integer()) :: :ok | {:error, term()}
  def delete(webhook_id) do
    case EDA.HTTP.Client.delete("/webhooks/#{webhook_id}") do
      {:ok, _} -> :ok
      error -> error
    end
  end

  @doc """
  Executes a webhook.

  Pass `wait: true` in opts to receive the created message back (required for
  subsequent `get_message/3`, `edit_message/4`, `delete_message/3`).
  Without `wait: true`, Discord returns 204 No Content, and this `{:ok, nil}`.
  """
  @spec execute(String.t() | integer(), String.t(), map() | keyword()) ::
          {:ok, map() | nil} | {:error, term()}
  def execute(webhook_id, webhook_token, opts) when is_list(opts) do
    check_options!(
      opts,
      @execute_body ++ @execute_query ++ @builder_keys,
      "EDA.API.Webhook.execute/3"
    )

    {query, opts} = Keyword.split(opts, @execute_query)
    url = webhook_path(webhook_id, webhook_token, query)

    case build_message_payload(opts) do
      {payload, files} ->
        request_multipart(:post, url, payload, files)

      payload ->
        post(url, payload)
    end
  end

  def execute(webhook_id, webhook_token, opts) when is_map(opts) do
    check_options!(opts, @execute_body ++ @execute_query, "EDA.API.Webhook.execute/3")
    {query, body} = Map.split(opts, @execute_query)
    post(webhook_path(webhook_id, webhook_token, Map.to_list(query)), body)
  end

  @doc """
  Gets a message previously sent by a webhook.

  Uses webhook token authentication (no bot token required).

  ## Examples

      {:ok, msg} = Webhook.get_message(webhook_id, token, message_id)
  """
  @spec get_message(String.t() | integer(), String.t(), String.t() | integer()) ::
          {:ok, map()} | {:error, term()}
  def get_message(webhook_id, webhook_token, message_id) do
    EDA.HTTP.Client.get("/webhooks/#{webhook_id}/#{webhook_token}/messages/#{message_id}")
  end

  @doc """
  Edits a message previously sent by a webhook.

  Accepts a map or keyword list of message fields to update (`content`, `embeds`,
  `components`, `allowed_mentions`). Supports file attachments via keyword opts.

  ## Examples

      {:ok, edited} = Webhook.edit_message(wh_id, token, msg_id, %{content: "updated"})
      {:ok, edited} = Webhook.edit_message(wh_id, token, msg_id, content: "updated")
  """
  @spec edit_message(
          String.t() | integer(),
          String.t(),
          String.t() | integer(),
          map() | keyword()
        ) ::
          {:ok, map()} | {:error, term()}
  def edit_message(webhook_id, webhook_token, message_id, opts) when is_list(opts) do
    check_options!(
      opts,
      @edit_body ++ @edit_query ++ @builder_keys,
      "EDA.API.Webhook.edit_message/4"
    )

    {query, opts} = Keyword.split(opts, @edit_query)
    path = with_query("/webhooks/#{webhook_id}/#{webhook_token}/messages/#{message_id}", query)

    case build_message_payload(opts) do
      {payload, files} -> request_multipart(:patch, path, payload, files)
      payload -> patch(path, payload)
    end
  end

  def edit_message(webhook_id, webhook_token, message_id, opts) when is_map(opts) do
    check_options!(opts, @edit_body ++ @edit_query, "EDA.API.Webhook.edit_message/4")
    {query, body} = Map.split(opts, @edit_query)

    patch(
      with_query(
        "/webhooks/#{webhook_id}/#{webhook_token}/messages/#{message_id}",
        Map.to_list(query)
      ),
      body
    )
  end

  @doc """
  Deletes a message previously sent by a webhook.

  Uses webhook token authentication (no bot token required).

  ## Examples

      :ok = Webhook.delete_message(webhook_id, token, message_id)
  """
  @spec delete_message(String.t() | integer(), String.t(), String.t() | integer()) ::
          :ok | {:error, term()}
  def delete_message(webhook_id, webhook_token, message_id) do
    case EDA.HTTP.Client.delete("/webhooks/#{webhook_id}/#{webhook_token}/messages/#{message_id}") do
      {:ok, _} -> :ok
      error -> error
    end
  end

  # `wait: false` is Discord's default, so it is dropped rather than sent.
  defp webhook_path(webhook_id, webhook_token, query) do
    query = Enum.reject(query, fn {key, value} -> key == :wait and value in [false, nil] end)
    with_query("/webhooks/#{webhook_id}/#{webhook_token}", query)
  end
end
