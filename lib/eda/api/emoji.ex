defmodule EDA.API.Emoji do
  @moduledoc """
  REST API endpoints for Discord guild emojis.

  All functions return `{:ok, result}` or `{:error, reason}`.
  """

  import EDA.HTTP.Client

  @doc "Lists all emojis for a guild. Returns `EDA.Emoji` structs."
  @spec list(String.t() | integer()) :: {:ok, [EDA.Emoji.t()]} | {:error, term()}
  def list(guild_id) do
    case EDA.HTTP.Client.get("/guilds/#{guild_id}/emojis") do
      {:ok, emojis} -> {:ok, Enum.map(emojis, &EDA.Emoji.from_raw/1)}
      error -> error
    end
  end

  @doc "Gets a guild emoji by ID. Returns an `EDA.Emoji` struct."
  @spec get(String.t() | integer(), String.t() | integer()) ::
          {:ok, EDA.Emoji.t()} | {:error, term()}
  def get(guild_id, emoji_id) do
    case EDA.HTTP.Client.get("/guilds/#{guild_id}/emojis/#{emoji_id}") do
      {:ok, data} -> {:ok, EDA.Emoji.from_raw(data)}
      error -> error
    end
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
  @spec create(String.t() | integer(), map()) :: {:ok, EDA.Emoji.t()} | {:error, term()}
  def create(guild_id, params) do
    case post("/guilds/#{guild_id}/emojis", params) do
      {:ok, data} -> {:ok, EDA.Emoji.from_raw(data)}
      error -> error
    end
  end

  @doc "Modifies a guild emoji."
  @spec modify(String.t() | integer(), String.t() | integer(), map()) ::
          {:ok, EDA.Emoji.t()} | {:error, term()}
  def modify(guild_id, emoji_id, params) do
    case patch("/guilds/#{guild_id}/emojis/#{emoji_id}", params) do
      {:ok, data} -> {:ok, EDA.Emoji.from_raw(data)}
      error -> error
    end
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

  @doc "Lists the application's emojis. Returns `EDA.Emoji` structs."
  @spec list_application() :: {:ok, [EDA.Emoji.t()]} | {:error, term()}
  def list_application do
    case EDA.HTTP.Client.get("/applications/#{app_id()}/emojis") do
      {:ok, %{"items" => emojis}} -> {:ok, Enum.map(emojis, &EDA.Emoji.from_raw/1)}
      {:ok, emojis} when is_list(emojis) -> {:ok, Enum.map(emojis, &EDA.Emoji.from_raw/1)}
      error -> error
    end
  end

  @doc "Gets one of the application's emojis."
  @spec get_application(String.t() | integer()) :: {:ok, EDA.Emoji.t()} | {:error, term()}
  def get_application(emoji_id) do
    case EDA.HTTP.Client.get("/applications/#{app_id()}/emojis/#{emoji_id}") do
      {:ok, data} -> {:ok, EDA.Emoji.from_raw(data)}
      error -> error
    end
  end

  @doc """
  Creates an application emoji.

  `image` is a path, raw PNG/JPEG/GIF bytes or a data URI — see `EDA.ImageData`. Discord takes a
  128×128 image of at most 256 KiB, and refuses a larger one with a bare 400.
  """
  @spec create_application(String.t(), String.t() | binary()) ::
          {:ok, EDA.Emoji.t()} | {:error, term()}
  def create_application(name, image) when is_binary(name) do
    case post("/applications/#{app_id()}/emojis", %{
           name: name,
           image: EDA.ImageData.coerce(image)
         }) do
      {:ok, data} -> {:ok, EDA.Emoji.from_raw(data)}
      error -> error
    end
  end

  @doc "Renames an application emoji — the only thing that can change about one."
  @spec modify_application(String.t() | integer(), String.t()) ::
          {:ok, EDA.Emoji.t()} | {:error, term()}
  def modify_application(emoji_id, name) when is_binary(name) do
    case patch("/applications/#{app_id()}/emojis/#{emoji_id}", %{name: name}) do
      {:ok, data} -> {:ok, EDA.Emoji.from_raw(data)}
      error -> error
    end
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
