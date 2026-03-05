defmodule EDA.API.Webhook do
  @moduledoc """
  REST API endpoints for Discord webhooks.

  All functions return `{:ok, result}` or `{:error, reason}`.
  """

  import EDA.HTTP.Client

  @doc "Creates a webhook for a channel."
  @spec create(String.t() | integer(), map()) :: {:ok, map()} | {:error, term()}
  def create(channel_id, opts) do
    post("/channels/#{channel_id}/webhooks", opts)
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
  @spec modify(String.t() | integer(), map()) :: {:ok, map()} | {:error, term()}
  def modify(webhook_id, opts) do
    patch("/webhooks/#{webhook_id}", opts)
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
  Without `wait: true`, Discord returns 204 No Content.
  """
  @spec execute(String.t() | integer(), String.t(), map() | keyword()) ::
          {:ok, map()} | {:error, term()}
  def execute(webhook_id, webhook_token, opts) when is_list(opts) do
    {wait, opts} = Keyword.pop(opts, :wait, false)
    url = webhook_url(webhook_id, webhook_token, wait)

    case build_message_payload(opts) do
      {payload, files} ->
        request_multipart(:post, url, payload, files)

      payload ->
        post(url, payload)
    end
  end

  def execute(webhook_id, webhook_token, opts) when is_map(opts) do
    {wait, opts} = Map.pop(opts, :wait, false)
    post(webhook_url(webhook_id, webhook_token, wait), opts)
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
    case build_message_payload(opts) do
      {payload, files} ->
        request_multipart(
          :patch,
          "/webhooks/#{webhook_id}/#{webhook_token}/messages/#{message_id}",
          payload,
          files
        )

      payload ->
        patch("/webhooks/#{webhook_id}/#{webhook_token}/messages/#{message_id}", payload)
    end
  end

  def edit_message(webhook_id, webhook_token, message_id, opts) when is_map(opts) do
    patch("/webhooks/#{webhook_id}/#{webhook_token}/messages/#{message_id}", opts)
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

  defp webhook_url(webhook_id, webhook_token, true),
    do: "/webhooks/#{webhook_id}/#{webhook_token}?wait=true"

  defp webhook_url(webhook_id, webhook_token, _),
    do: "/webhooks/#{webhook_id}/#{webhook_token}"
end
