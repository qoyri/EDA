defmodule EDA.Webhook do
  @moduledoc "Represents a Discord webhook."
  use EDA.Event.Access

  @types %{1 => :incoming, 2 => :channel_follower, 3 => :application}

  defstruct [
    :id,
    :type,
    :guild_id,
    :channel_id,
    :user,
    :name,
    :avatar,
    :token,
    :application_id,
    :source_guild,
    :source_channel,
    :url
  ]

  @type t :: %__MODULE__{
          id: String.t() | nil,
          type: :incoming | :channel_follower | :application | integer() | nil,
          guild_id: String.t() | nil,
          channel_id: String.t() | nil,
          user: EDA.User.t() | nil,
          name: String.t() | nil,
          avatar: String.t() | nil,
          token: String.t() | nil,
          application_id: String.t() | nil,
          source_guild: EDA.Guild.t() | nil,
          source_channel: EDA.Channel.t() | nil,
          url: String.t() | nil
        }

  @spec from_raw(map()) :: t()
  def from_raw(%__MODULE__{} = parsed), do: parsed

  def from_raw(raw) when is_map(raw) do
    %__MODULE__{
      id: :maps.get("id", raw, nil),
      type: EDA.Enum.name(@types, :maps.get("type", raw, nil)),
      guild_id: :maps.get("guild_id", raw, nil),
      channel_id: :maps.get("channel_id", raw, nil),
      user: parse_user(:maps.get("user", raw, nil)),
      name: :maps.get("name", raw, nil),
      avatar: :maps.get("avatar", raw, nil),
      token: :maps.get("token", raw, nil),
      application_id: :maps.get("application_id", raw, nil),
      source_guild:
        :maps.get("source_guild", raw, nil) &&
          EDA.Guild.from_raw(:maps.get("source_guild", raw, nil)),
      source_channel:
        :maps.get("source_channel", raw, nil) &&
          EDA.Channel.from_raw(:maps.get("source_channel", raw, nil)),
      url: :maps.get("url", raw, nil)
    }
  end

  defp parse_user(nil), do: nil
  defp parse_user(raw) when is_map(raw), do: EDA.User.from_raw(raw)

  # ── Entity Manager ──

  use EDA.Entity

  @doc "Creates a webhook in a channel. Takes `:name` and an optional `:avatar`."
  @spec create(EDA.Channel.t() | String.t() | integer(), map() | keyword()) ::
          {:ok, t()} | {:error, term()}
  def create(channel, opts), do: EDA.API.Webhook.create(id_of(channel), opts) |> parse_response()

  @doc "Lists a channel's webhooks."
  @spec list_channel(EDA.Channel.t() | String.t() | integer()) :: {:ok, [t()]} | {:error, term()}
  def list_channel(channel), do: EDA.API.Webhook.list_channel(id_of(channel)) |> parse_list()

  @doc "Lists a guild's webhooks."
  @spec list_guild(String.t() | integer()) :: {:ok, [t()]} | {:error, term()}
  def list_guild(guild_id), do: EDA.API.Webhook.list_guild(guild_id) |> parse_list()

  @doc "Fetches a webhook by id."
  @spec fetch(String.t() | integer()) :: {:ok, t()} | {:error, term()}
  def fetch(webhook_id), do: EDA.API.Webhook.get(webhook_id) |> parse_response()

  @doc "Modifies a webhook: its `:name`, `:avatar` or `:channel_id`."
  @spec modify(t() | String.t() | integer(), map() | keyword()) :: {:ok, t()} | {:error, term()}
  def modify(webhook, opts), do: EDA.API.Webhook.modify(id_of(webhook), opts) |> parse_response()

  @doc "Deletes a webhook."
  @spec delete(t() | String.t() | integer()) :: :ok | {:error, term()}
  def delete(webhook), do: EDA.API.Webhook.delete(id_of(webhook))

  @doc """
  Sends a message through the webhook, which must carry its `token` (an incoming webhook the
  bot created or fetched). Takes the options of `EDA.API.Webhook.execute/3`.

  With `wait: true`, returns the message sent, as an `EDA.Message`; otherwise `:ok`.
  """
  @spec execute(t(), map() | keyword()) :: {:ok, EDA.Message.t()} | :ok | {:error, term()}
  def execute(%__MODULE__{id: id, token: token}, opts),
    do: EDA.API.Webhook.execute(id, token, opts) |> parse_message()

  @doc "Fetches a message the webhook sent."
  @spec fetch_message(t(), EDA.Message.t() | String.t() | integer()) ::
          {:ok, EDA.Message.t()} | {:error, term()}
  def fetch_message(%__MODULE__{id: id, token: token}, message),
    do: EDA.API.Webhook.get_message(id, token, id_of(message)) |> parse_message()

  @doc "Edits a message the webhook sent. Takes the options of `EDA.API.Webhook.edit_message/4`."
  @spec edit_message(t(), EDA.Message.t() | String.t() | integer(), map() | keyword()) ::
          {:ok, EDA.Message.t()} | {:error, term()}
  def edit_message(%__MODULE__{id: id, token: token}, message, opts),
    do: EDA.API.Webhook.edit_message(id, token, id_of(message), opts) |> parse_message()

  @doc "Deletes a message the webhook sent."
  @spec delete_message(t(), EDA.Message.t() | String.t() | integer()) :: :ok | {:error, term()}
  def delete_message(%__MODULE__{id: id, token: token}, message),
    do: EDA.API.Webhook.delete_message(id, token, id_of(message))

  defp id_of(%{id: id}), do: id
  defp id_of(id), do: id

  defp parse_message({:ok, raw}) when is_map(raw), do: {:ok, EDA.Message.from_raw(raw)}
  defp parse_message({:ok, nil}), do: :ok
  defp parse_message(other), do: other

  defp parse_list({:ok, list}) when is_list(list), do: {:ok, Enum.map(list, &from_raw/1)}
  defp parse_list({:error, _} = err), do: err

  @doc """
  The webhook's URL, with its token, to post to it from anywhere; `nil` for a webhook without
  a token (a channel follower, or one fetched without MANAGE_WEBHOOKS).

      iex> EDA.Webhook.url(%EDA.Webhook{id: "1", token: "t"})
      "https://discord.com/api/webhooks/1/t"
  """
  @spec url(t()) :: String.t() | nil
  def url(%__MODULE__{token: nil}), do: nil

  def url(%__MODULE__{id: id, token: token}),
    do: "https://discord.com/api/webhooks/#{id}/#{token}"
end
