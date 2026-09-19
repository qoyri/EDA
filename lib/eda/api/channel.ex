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
    post("/guilds/#{guild_id}/channels", payload, opts)
  end

  @doc "Modifies guild channel positions."
  @spec modify_positions(String.t() | integer(), [map()]) :: :ok | {:error, term()}
  def modify_positions(guild_id, positions) do
    case patch("/guilds/#{guild_id}/channels", positions) do
      {:ok, _} -> :ok
      error -> error
    end
  end

  @doc "Edits channel permission overwrites for a user or role."
  @spec edit_permissions(String.t() | integer(), String.t() | integer(), map()) ::
          :ok | {:error, term()}
  def edit_permissions(channel_id, overwrite_id, opts) do
    case put("/channels/#{channel_id}/permissions/#{overwrite_id}", opts) do
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
end
