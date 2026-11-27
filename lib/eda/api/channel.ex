defmodule EDA.API.Channel do
  @moduledoc """
  REST API endpoints for Discord channels.

  All functions return `{:ok, result}` or `{:error, reason}`.
  """

  import EDA.HTTP.Client

  @doc "Gets a channel by ID."
  @spec get(String.t() | integer()) :: {:ok, map()} | {:error, term()}
  def get(channel_id) do
    EDA.HTTP.Client.get("/channels/#{channel_id}")
  end

  @doc "Modifies a channel."
  @spec modify(String.t() | integer(), map(), keyword()) :: {:ok, map()} | {:error, term()}
  def modify(channel_id, payload, opts \\ []) do
    patch("/channels/#{channel_id}", payload, opts)
  end

  @doc "Deletes a channel."
  @spec delete(String.t() | integer(), keyword()) :: {:ok, map()} | {:error, term()}
  def delete(channel_id, opts \\ []) do
    EDA.HTTP.Client.delete("/channels/#{channel_id}", Keyword.put_new(opts, :priority, :urgent))
  end

  @doc "Creates a channel in a guild."
  @spec create(String.t() | integer(), map(), keyword()) :: {:ok, map()} | {:error, term()}
  def create(guild_id, payload, opts \\ []) do
    payload = EDA.Enum.encode(Map.new(payload), type: &EDA.Channel.type_value/1)
    post("/guilds/#{guild_id}/channels", payload, opts)
  end

  @doc """
  Modifies guild channel positions. Takes `[%{id: channel_id, position: n}]`; an entry may also
  move the channel with `parent_id`, and `lock_permissions` then syncs its overwrites with the
  new category.

  With `reason:`, the reorder is recorded with it, as one `:channel_position_update` audit log
  entry; an entry that changes `parent_id` is recorded as a `:channel_update` of that channel.
  """
  @spec modify_positions(String.t() | integer(), [map()], keyword()) :: :ok | {:error, term()}
  def modify_positions(guild_id, positions, opts \\ []) do
    case patch("/guilds/#{guild_id}/channels", positions, opts) do
      {:ok, _} -> :ok
      error -> error
    end
  end

  @doc """
  Gets a member's permissions in a channel as Discord computes them, from their roles and the
  channel's overwrites; a thread uses its parent's. The bot needs `VIEW_CHANNEL` there, and
  `CONNECT` for a voice or stage channel.

  By default the result is masked as Discord masks it — what the channel grants is removed
  without `VIEW_CHANNEL`, or without `CONNECT` in a voice or stage channel — except when the
  member is a bot. `implicit: false` returns the permissions before that masking.

  Returns `%{"permissions" => "<bitfield>"}`; `EDA.Permission.fetch_in_channel/3` returns the
  bitset.
  """
  @spec member_permissions(String.t() | integer(), String.t() | integer(), keyword()) ::
          {:ok, map()} | {:error, term()}
  def member_permissions(channel_id, user_id, opts \\ []) do
    EDA.HTTP.Client.get(
      with_query("/channels/#{channel_id}/permissions/member/#{user_id}", opts, [:implicit])
    )
  end

  @doc """
  Gets the permissions a role gives in a channel, combined with `@everyone` and with the
  overwrites of both — no other role, and no member overwrite. Takes `implicit:` like
  `member_permissions/3`.

  Returns `%{"permissions" => "<bitfield>"}`; `EDA.Permission.fetch_for_role_in_channel/3`
  returns the bitset.
  """
  @spec role_permissions(String.t() | integer(), String.t() | integer(), keyword()) ::
          {:ok, map()} | {:error, term()}
  def role_permissions(channel_id, role_id, opts \\ []) do
    EDA.HTTP.Client.get(
      with_query("/channels/#{channel_id}/permissions/role/#{role_id}", opts, [:implicit])
    )
  end

  @doc "Edits channel permission overwrites for a user or role."
  @spec edit_permissions(String.t() | integer(), String.t() | integer(), map() | keyword()) ::
          :ok | {:error, term()}
  def edit_permissions(channel_id, overwrite_id, opts) do
    body = Map.new(opts)
    # `alow:` would be dropped by Discord, leaving an overwrite that grants nothing.
    check_options!(body, [:allow, :deny, :type], "EDA.API.Channel.edit_permissions/3")
    body = EDA.Enum.encode(body, type: &EDA.PermissionOverwrite.type_value/1)

    case put("/channels/#{channel_id}/permissions/#{overwrite_id}", body) do
      {:ok, _} -> :ok
      error -> error
    end
  end

  @doc "Deletes channel permission overwrites for a user or role."
  @spec delete_permissions(String.t() | integer(), String.t() | integer()) ::
          :ok | {:error, term()}
  def delete_permissions(channel_id, overwrite_id) do
    case EDA.HTTP.Client.delete("/channels/#{channel_id}/permissions/#{overwrite_id}") do
      {:ok, _} -> :ok
      error -> error
    end
  end

  @doc "Triggers the typing indicator in a channel."
  @spec trigger_typing(String.t() | integer()) :: :ok | {:error, term()}
  def trigger_typing(channel_id) do
    case post("/channels/#{channel_id}/typing", %{}) do
      {:ok, _} -> :ok
      error -> error
    end
  end

  @doc """
  Sets a voice channel's status (up to 500 characters, or `nil` to clear it).

  Requires the `SET_VOICE_CHANNEL_STATUS` permission, plus `MANAGE_CHANNELS`
  if the bot is not connected to the channel.

  ## Options

  - `:reason` - Audit log reason
  """
  @spec set_voice_status(String.t() | integer(), String.t() | nil, keyword()) ::
          :ok | {:error, term()}
  def set_voice_status(channel_id, status, opts \\ []) do
    case put("/channels/#{channel_id}/voice-status", %{status: status}, opts) do
      {:ok, _} -> :ok
      error -> error
    end
  end

  @doc """
  Follows an announcement channel: its published messages are then posted to `target_channel_id`
  through a webhook Discord creates there.

  `POST /channels/{channel_id}/followers`. Needs `MANAGE_WEBHOOKS` in the target channel. Returns
  `%{"channel_id" => source, "webhook_id" => id}`.

  ## Options

    * `:reason` — audit log reason
  """
  @spec follow(String.t() | integer(), String.t() | integer(), keyword()) ::
          {:ok, map()} | {:error, term()}
  def follow(channel_id, target_channel_id, opts \\ []) do
    check_options!(opts, [:reason], "EDA.API.Channel.follow/3")

    post(
      "/channels/#{channel_id}/followers",
      %{webhook_channel_id: to_string(target_channel_id)},
      opts
    )
  end
end
