defmodule EDA.API.Command do
  @moduledoc """
  REST API endpoints for Discord application commands.

  All functions return `{:ok, result}` or `{:error, reason}`.
  """

  import EDA.HTTP.Client

  @doc "Creates a global application command."
  @spec create_global(map() | EDA.Command.t()) :: {:ok, map()} | {:error, term()}
  def create_global(command) do
    post("/applications/#{app_id()}/commands", command_to_map(command))
  end

  @doc "Creates a guild application command (available instantly)."
  @spec create_guild(String.t() | integer(), map() | EDA.Command.t()) ::
          {:ok, map()} | {:error, term()}
  def create_guild(guild_id, command) do
    post("/applications/#{app_id()}/guilds/#{guild_id}/commands", command_to_map(command))
  end

  @doc "Fetches all global application commands."
  @spec list_global() :: {:ok, [map()]} | {:error, term()}
  def list_global do
    EDA.HTTP.Client.get("/applications/#{app_id()}/commands")
  end

  @doc "Fetches all guild application commands."
  @spec list_guild(String.t() | integer()) :: {:ok, [map()]} | {:error, term()}
  def list_guild(guild_id) do
    EDA.HTTP.Client.get("/applications/#{app_id()}/guilds/#{guild_id}/commands")
  end

  @doc "Updates a global application command."
  @spec edit_global(String.t() | integer(), map()) :: {:ok, map()} | {:error, term()}
  def edit_global(command_id, command) do
    patch("/applications/#{app_id()}/commands/#{command_id}", command_to_map(command))
  end

  @doc "Updates a guild application command."
  @spec edit_guild(String.t() | integer(), String.t() | integer(), map()) ::
          {:ok, map()} | {:error, term()}
  def edit_guild(guild_id, command_id, command) do
    patch(
      "/applications/#{app_id()}/guilds/#{guild_id}/commands/#{command_id}",
      command_to_map(command)
    )
  end

  @doc "Deletes a global application command."
  @spec delete_global(String.t() | integer()) :: :ok | {:error, term()}
  def delete_global(command_id) do
    case EDA.HTTP.Client.delete("/applications/#{app_id()}/commands/#{command_id}") do
      {:ok, _} -> :ok
      error -> error
    end
  end

  @doc "Deletes a guild application command."
  @spec delete_guild(String.t() | integer(), String.t() | integer()) :: :ok | {:error, term()}
  def delete_guild(guild_id, command_id) do
    case EDA.HTTP.Client.delete(
           "/applications/#{app_id()}/guilds/#{guild_id}/commands/#{command_id}"
         ) do
      {:ok, _} -> :ok
      error -> error
    end
  end

  @doc "Bulk overwrites all global application commands."
  @spec bulk_overwrite_global([map() | EDA.Command.t()]) :: {:ok, [map()]} | {:error, term()}
  def bulk_overwrite_global(commands) do
    put("/applications/#{app_id()}/commands", Enum.map(commands, &command_to_map/1))
  end

  @doc "Bulk overwrites all guild application commands."
  @spec bulk_overwrite_guild(String.t() | integer(), [map() | EDA.Command.t()]) ::
          {:ok, [map()]} | {:error, term()}
  def bulk_overwrite_guild(guild_id, commands) do
    put(
      "/applications/#{app_id()}/guilds/#{guild_id}/commands",
      Enum.map(commands, &command_to_map/1)
    )
  end

  @doc """
  Gets who may use each of the app's commands in a guild — every command with permissions set
  there, and the app-wide entry whose `id` is the application id.

  `EDA.Command.Permissions.from_raw/1` parses each. Setting them needs a user's OAuth2 token, not
  a bot's, so there is no write counterpart here.
  """
  @spec permissions(String.t() | integer()) :: {:ok, [map()]} | {:error, term()}
  def permissions(guild_id) do
    EDA.HTTP.Client.get("/applications/#{app_id()}/guilds/#{guild_id}/commands/permissions")
  end

  @doc "Gets who may use one of the app's commands in a guild. See `permissions/1`."
  @spec permissions(String.t() | integer(), String.t() | integer()) ::
          {:ok, map()} | {:error, term()}
  def permissions(guild_id, command_id) do
    EDA.HTTP.Client.get(
      "/applications/#{app_id()}/guilds/#{guild_id}/commands/#{command_id}/permissions"
    )
  end
end
