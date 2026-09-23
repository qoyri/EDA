defmodule EDA.API.GuildTemplate do
  @moduledoc """
  REST API endpoints for Discord guild templates.

  All functions return `{:ok, result}` or `{:error, reason}`.
  """

  import EDA.HTTP.Client

  @doc """
  Gets a guild template by its code.

  This endpoint does not require authentication.

  ## Parameters

  - `code` - The template code (e.g. `"hgM48av5Q69A"`)
  """
  @spec get(String.t()) :: {:ok, map()} | {:error, term()}
  def get(code) do
    EDA.HTTP.Client.get("/guilds/templates/#{code}")
  end

  @doc """
  Lists all templates for a guild.

  Requires the `MANAGE_GUILD` permission.

  ## Parameters

  - `guild_id` - The guild ID
  """
  @spec list(String.t() | integer()) :: {:ok, [map()]} | {:error, term()}
  def list(guild_id) do
    EDA.HTTP.Client.get("/guilds/#{guild_id}/templates")
  end

  @doc """
  Creates a guild template.

  Requires the `MANAGE_GUILD` permission.

  ## Parameters

  - `guild_id` - The guild ID
  - `params` - Map with:
    - `:name` - Template name (required, 1-100 chars)
    - `:description` - Template description (optional, 0-120 chars)
  """
  @spec create(String.t() | integer(), map()) :: {:ok, map()} | {:error, term()}
  def create(guild_id, params) do
    post("/guilds/#{guild_id}/templates", params)
  end

  @doc """
  Modifies a guild template's metadata.

  Requires the `MANAGE_GUILD` permission.

  ## Parameters

  - `guild_id` - The guild ID
  - `code` - The template code
  - `params` - Map with:
    - `:name` - Template name (optional, 1-100 chars)
    - `:description` - Template description (optional, 0-120 chars)
  """
  @spec modify(String.t() | integer(), String.t(), map()) ::
          {:ok, map()} | {:error, term()}
  def modify(guild_id, code, params) do
    patch("/guilds/#{guild_id}/templates/#{code}", params)
  end

  @doc """
  Syncs a guild template with the current guild state.

  Requires the `MANAGE_GUILD` permission. This is a PUT with no body.

  ## Parameters

  - `guild_id` - The guild ID
  - `code` - The template code
  """
  @spec sync(String.t() | integer(), String.t()) ::
          {:ok, map()} | {:error, term()}
  def sync(guild_id, code) do
    put("/guilds/#{guild_id}/templates/#{code}", %{})
  end

  @doc """
  Deletes a guild template. Returns the deleted template.

  Requires the `MANAGE_GUILD` permission.

  ## Parameters

  - `guild_id` - The guild ID
  - `code` - The template code
  """
  @spec delete(String.t() | integer(), String.t()) ::
          {:ok, map()} | {:error, term()}
  def delete(guild_id, code) do
    EDA.HTTP.Client.delete("/guilds/#{guild_id}/templates/#{code}")
  end

  @doc """
  Creates a new guild from a template.

  The bot must be in fewer than 10 guilds. Returns the raw guild object as a map.

  ## Parameters

  - `code` - The template code
  - `params` - Map with:
    - `:name` - Guild name (required, 2-100 chars)
    - `:icon` - Base64 128x128 image for the guild icon (optional)
  """
  @spec create_guild(String.t(), map()) :: {:ok, map()} | {:error, term()}
  def create_guild(code, params) do
    post("/guilds/templates/#{code}", params)
  end
end
