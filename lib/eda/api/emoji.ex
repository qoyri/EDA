defmodule EDA.API.Emoji do
  @moduledoc """
  REST API endpoints for Discord guild emojis.

  All functions return `{:ok, result}` or `{:error, reason}`.
  """

  import EDA.HTTP.Client

  @doc "Lists all emojis for a guild."
  @spec list(String.t() | integer()) :: {:ok, [map()]} | {:error, term()}
  def list(guild_id) do
    EDA.HTTP.Client.get("/guilds/#{guild_id}/emojis")
  end

  @doc "Gets a guild emoji by ID."
  @spec get(String.t() | integer(), String.t() | integer()) ::
          {:ok, map()} | {:error, term()}
  def get(guild_id, emoji_id) do
    EDA.HTTP.Client.get("/guilds/#{guild_id}/emojis/#{emoji_id}")
  end

  @doc """
  Creates a guild emoji.

  ## Parameters

  - `guild_id` - The guild ID
  - `params` - Map with:
    - `:name` - Emoji name (required)
    - `:image` - Base64-encoded image data URI (required)
    - `:roles` - List of role IDs allowed to use this emoji (optional)
  """
  @spec create(String.t() | integer(), map()) :: {:ok, map()} | {:error, term()}
  def create(guild_id, params) do
    post("/guilds/#{guild_id}/emojis", params)
  end

  @doc "Modifies a guild emoji."
  @spec modify(String.t() | integer(), String.t() | integer(), map()) ::
          {:ok, map()} | {:error, term()}
  def modify(guild_id, emoji_id, params) do
    patch("/guilds/#{guild_id}/emojis/#{emoji_id}", params)
  end

  @doc "Deletes a guild emoji."
  @spec delete(String.t() | integer(), String.t() | integer()) :: :ok | {:error, term()}
  def delete(guild_id, emoji_id) do
    case EDA.HTTP.Client.delete("/guilds/#{guild_id}/emojis/#{emoji_id}") do
      {:ok, _} -> :ok
      error -> error
    end
  end

  # ── Application emojis ─────────────────────────────────────────────
  #
  # Emojis owned by the application rather than a guild: up to 2000 of them, usable by the bot in
  # any guild, DM or channel without being uploaded anywhere.

  @doc "Lists the application's emojis."
  @spec list_application() :: {:ok, [map()]} | {:error, term()}
  def list_application do
    # Discord wraps this list in `items`, unlike every other list endpoint.
    case EDA.HTTP.Client.get("/applications/#{app_id()}/emojis") do
      {:ok, %{"items" => emojis}} -> {:ok, emojis}
      other -> other
    end
  end

  @doc "Gets one of the application's emojis."
  @spec get_application(String.t() | integer()) :: {:ok, map()} | {:error, term()}
  def get_application(emoji_id) do
    EDA.HTTP.Client.get("/applications/#{app_id()}/emojis/#{emoji_id}")
  end

  @doc """
  Creates an application emoji.

  `image` is a path, raw PNG/JPEG/GIF bytes or a data URI — see `EDA.ImageData`. Discord takes a
  128×128 image of at most 256 KiB, and refuses a larger one with a bare 400.
  """
  @spec create_application(String.t(), String.t() | binary()) ::
          {:ok, map()} | {:error, term()}
  def create_application(name, image) when is_binary(name) do
    post("/applications/#{app_id()}/emojis", %{
      name: name,
      image: EDA.ImageData.coerce(image)
    })
  end

  @doc "Renames an application emoji — the only thing that can change about one."
  @spec modify_application(String.t() | integer(), String.t()) ::
          {:ok, map()} | {:error, term()}
  def modify_application(emoji_id, name) when is_binary(name) do
    patch("/applications/#{app_id()}/emojis/#{emoji_id}", %{name: name})
  end

  @doc "Deletes an application emoji."
  @spec delete_application(String.t() | integer()) :: :ok | {:error, term()}
  def delete_application(emoji_id) do
    case EDA.HTTP.Client.delete("/applications/#{app_id()}/emojis/#{emoji_id}") do
      {:ok, _} -> :ok
      error -> error
    end
  end
end
