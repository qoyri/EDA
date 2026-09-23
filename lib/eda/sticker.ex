defmodule EDA.Sticker do
  @moduledoc """
  Represents a Discord sticker.

  Types: `:standard` (Nitro stickers), `:guild` (guild-specific).
  Formats: `:png`, `:apng`, `:lottie`, `:gif`.
  """

  use EDA.Event.Access

  defstruct [
    :id,
    :pack_id,
    :name,
    :description,
    :tags,
    :type,
    :format_type,
    :available,
    :guild_id,
    :user,
    :sort_value
  ]

  @type t :: %__MODULE__{
          id: String.t() | nil,
          pack_id: String.t() | nil,
          name: String.t() | nil,
          description: String.t() | nil,
          tags: String.t() | nil,
          type: :standard | :guild | integer() | nil,
          format_type: :png | :apng | :lottie | :gif | integer() | nil,
          available: boolean() | nil,
          guild_id: String.t() | nil,
          user: EDA.User.t() | nil,
          sort_value: integer() | nil
        }

  @sticker_types %{1 => :standard, 2 => :guild}
  @format_types %{1 => :png, 2 => :apng, 3 => :lottie, 4 => :gif}

  @discord_cdn "https://cdn.discordapp.com"

  @doc """
  Converts a raw Discord sticker map into this struct.

  Resolves integer `type` and `format_type` to atoms where known.

  ## Examples

      iex> EDA.Sticker.from_raw(%{"id" => "1", "name" => "wave", "type" => 2, "format_type" => 1})
      %EDA.Sticker{id: "1", name: "wave", type: :guild, format_type: :png}
  """
  @spec from_raw(map()) :: t()
  def from_raw(raw) when is_map(raw) do
    %__MODULE__{
      id: raw["id"],
      pack_id: raw["pack_id"],
      name: raw["name"],
      description: raw["description"],
      tags: raw["tags"],
      type: resolve_type(raw["type"]),
      format_type: resolve_format(raw["format_type"]),
      available: raw["available"],
      guild_id: raw["guild_id"],
      user: parse_user(raw["user"]),
      sort_value: raw["sort_value"]
    }
  end

  @doc """
  Returns the CDN URL for a sticker.

  Lottie stickers return a `.json` URL, GIF stickers return `.gif`,
  and all others return `.png`. Returns `nil` if the sticker has no id.

  ## Examples

      iex> EDA.Sticker.cdn_url(%EDA.Sticker{id: "1", format_type: :lottie})
      "https://cdn.discordapp.com/stickers/1.json"

      iex> EDA.Sticker.cdn_url(%EDA.Sticker{id: "1", format_type: :gif})
      "https://cdn.discordapp.com/stickers/1.gif"

      iex> EDA.Sticker.cdn_url(%EDA.Sticker{id: "1", format_type: :png})
      "https://cdn.discordapp.com/stickers/1.png"

      iex> EDA.Sticker.cdn_url(%EDA.Sticker{id: nil})
      nil
  """
  @spec cdn_url(t()) :: String.t() | nil
  def cdn_url(%__MODULE__{id: nil}), do: nil

  def cdn_url(%__MODULE__{id: id, format_type: :lottie}),
    do: "#{@discord_cdn}/stickers/#{id}.json"

  def cdn_url(%__MODULE__{id: id, format_type: :gif}), do: "#{@discord_cdn}/stickers/#{id}.gif"
  def cdn_url(%__MODULE__{id: id}), do: "#{@discord_cdn}/stickers/#{id}.png"

  defp resolve_type(int) when is_integer(int), do: Map.get(@sticker_types, int, int)
  defp resolve_type(other), do: other

  @doc false
  # Shared with EDA.Sticker.Item.
  def resolve_format(int) when is_integer(int), do: Map.get(@format_types, int, int)
  def resolve_format(other), do: other

  defp parse_user(nil), do: nil
  defp parse_user(raw) when is_map(raw), do: EDA.User.from_raw(raw)

  # ── Entity Manager ──

  use EDA.Entity

  @doc "Lists a guild's stickers."
  @spec list(String.t() | integer()) :: {:ok, [t()]} | {:error, term()}
  def list(guild_id), do: EDA.API.Sticker.list(guild_id) |> parse_list()

  @doc """
  Fetches a sticker by id: a guild's or a standard one from a pack.
  """
  @spec fetch(String.t() | integer()) :: {:ok, t()} | {:error, term()}
  def fetch(sticker_id), do: EDA.API.Sticker.get(sticker_id) |> parse_response()

  @doc """
  Fetches one of a guild's stickers, with the `user` who uploaded it when the bot can manage
  the guild's expressions.

  Named `fetch_sticker/2` rather than `fetch/2` because `Access.fetch/2` owns that arity.
  """
  @spec fetch_sticker(String.t() | integer(), String.t() | integer()) ::
          {:ok, t()} | {:error, term()}
  def fetch_sticker(guild_id, sticker_id),
    do: EDA.API.Sticker.get_guild(guild_id, sticker_id) |> parse_response()

  @doc "Uploads a guild sticker. Takes the parameters of `EDA.API.Sticker.create/2`."
  @spec create(String.t() | integer(), map()) :: {:ok, t()} | {:error, term()}
  def create(guild_id, params), do: EDA.API.Sticker.create(guild_id, params) |> parse_response()

  @doc "Modifies a guild sticker: its `name`, `description` or `tags`."
  @spec modify(String.t() | integer(), t() | String.t() | integer(), map()) ::
          {:ok, t()} | {:error, term()}
  def modify(guild_id, %__MODULE__{id: id}, params), do: modify(guild_id, id, params)

  def modify(guild_id, sticker_id, params),
    do: EDA.API.Sticker.modify(guild_id, sticker_id, params) |> parse_response()

  @doc "Deletes a guild sticker."
  @spec delete(String.t() | integer(), t() | String.t() | integer()) :: :ok | {:error, term()}
  def delete(guild_id, %__MODULE__{id: id}), do: delete(guild_id, id)
  def delete(guild_id, sticker_id), do: EDA.API.Sticker.delete_guild(guild_id, sticker_id)

  @doc "Lists the standard sticker packs, as `EDA.Sticker.Pack` structs."
  @spec list_packs() :: {:ok, [EDA.Sticker.Pack.t()]} | {:error, term()}
  def list_packs do
    case EDA.API.Sticker.list_packs() do
      {:ok, packs} when is_list(packs) -> {:ok, Enum.map(packs, &EDA.Sticker.Pack.from_raw/1)}
      {:error, _} = err -> err
    end
  end

  @doc "Fetches a standard sticker pack, as an `EDA.Sticker.Pack`."
  @spec fetch_pack(String.t() | integer()) :: {:ok, EDA.Sticker.Pack.t()} | {:error, term()}
  def fetch_pack(pack_id) do
    case EDA.API.Sticker.get_pack(pack_id) do
      {:ok, raw} when is_map(raw) -> {:ok, EDA.Sticker.Pack.from_raw(raw)}
      {:error, _} = err -> err
    end
  end

  defp parse_list({:ok, list}) when is_list(list), do: {:ok, Enum.map(list, &from_raw/1)}
  defp parse_list({:error, _} = err), do: err
end
