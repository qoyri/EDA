defmodule EDA.API.Sticker do
  @moduledoc """
  REST API endpoints for Discord stickers.

  All functions return `{:ok, result}` or `{:error, reason}`.
  """

  import EDA.HTTP.Client

  @doc "Lists all stickers for a guild."
  @spec list(String.t() | integer()) :: {:ok, [map()]} | {:error, term()}
  def list(guild_id) do
    EDA.HTTP.Client.get("/guilds/#{guild_id}/stickers")
  end

  @doc "Gets a guild sticker by ID."
  @spec get_guild(String.t() | integer(), String.t() | integer()) ::
          {:ok, map()} | {:error, term()}
  def get_guild(guild_id, sticker_id) do
    EDA.HTTP.Client.get("/guilds/#{guild_id}/stickers/#{sticker_id}")
  end

  @doc """
  Creates a guild sticker via multipart upload.

  ## Parameters

  - `guild_id` - The guild ID
  - `params` - Map with:
    - `:name` - Sticker name (required, 2-30 chars)
    - `:description` - Sticker description (required, 2-100 chars)
    - `:tags` - Autocomplete/suggestion tags (required, max 200 chars)
    - `:file` - An `EDA.File` struct with the sticker image data
  """
  @spec create(String.t() | integer(), map()) :: {:ok, map()} | {:error, term()}
  def create(guild_id, params) do
    file = Map.fetch!(params, :file)
    json_fields = Map.drop(params, [:file])

    request_multipart(:post, "/guilds/#{guild_id}/stickers", json_fields, [file])
  end

  @doc "Modifies a guild sticker."
  @spec modify(String.t() | integer(), String.t() | integer(), map()) ::
          {:ok, map()} | {:error, term()}
  def modify(guild_id, sticker_id, params) do
    patch("/guilds/#{guild_id}/stickers/#{sticker_id}", params)
  end

  @doc "Deletes a guild sticker."
  @spec delete_guild(String.t() | integer(), String.t() | integer()) :: :ok | {:error, term()}
  def delete_guild(guild_id, sticker_id) do
    case EDA.HTTP.Client.delete("/guilds/#{guild_id}/stickers/#{sticker_id}") do
      {:ok, _} -> :ok
      error -> error
    end
  end

  @doc "Gets a sticker by ID (any sticker, not guild-specific)."
  @spec get(String.t() | integer()) :: {:ok, map()} | {:error, term()}
  def get(sticker_id) do
    EDA.HTTP.Client.get("/stickers/#{sticker_id}")
  end

  @doc "Lists all available sticker packs (Nitro stickers)."
  @spec list_packs() :: {:ok, [map()]} | {:error, term()}
  def list_packs do
    case EDA.HTTP.Client.get("/sticker-packs") do
      {:ok, %{"sticker_packs" => packs}} -> {:ok, packs}
      other -> other
    end
  end

  @doc "Gets a sticker pack by ID."
  @spec get_pack(String.t() | integer()) :: {:ok, map()} | {:error, term()}
  def get_pack(pack_id) do
    EDA.HTTP.Client.get("/sticker-packs/#{pack_id}")
  end
end
