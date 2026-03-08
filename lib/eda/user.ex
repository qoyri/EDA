defmodule EDA.User do
  @moduledoc "Represents a Discord user."
  use EDA.Event.Access

  @discord_cdn "https://cdn.discordapp.com"

  defstruct [
    :id,
    :username,
    :avatar,
    :discriminator,
    :public_flags,
    :flags,
    :accent_color,
    :bot,
    :system,
    :banner,
    :global_name
  ]

  @type t :: %__MODULE__{
          id: String.t() | nil,
          username: String.t() | nil,
          avatar: String.t() | nil,
          discriminator: String.t() | nil,
          public_flags: integer() | nil,
          flags: integer() | nil,
          accent_color: integer() | nil,
          bot: boolean() | nil,
          system: boolean() | nil,
          banner: String.t() | nil,
          global_name: String.t() | nil
        }

  @spec from_raw(map()) :: t()
  def from_raw(raw) when is_map(raw) do
    %__MODULE__{
      id: raw["id"],
      username: raw["username"],
      avatar: raw["avatar"],
      discriminator: raw["discriminator"],
      public_flags: raw["public_flags"],
      flags: raw["flags"],
      accent_color: raw["accent_color"],
      bot: raw["bot"],
      system: raw["system"],
      banner: raw["banner"],
      global_name: raw["global_name"]
    }
  end

  @doc "Returns a mention string like `<@id>`. Accepts structs and raw maps."
  @spec mention(t() | map()) :: String.t()
  def mention(%__MODULE__{id: id}), do: "<@#{id}>"
  def mention(%{"id" => id}), do: "<@#{id}>"

  @doc """
  Returns the CDN URL for the user's avatar, or `nil` if none set.

  Accepts both `%EDA.User{}` structs and raw maps (from cache).
  """
  @spec avatar_url(t() | map()) :: String.t() | nil
  def avatar_url(%__MODULE__{avatar: nil}), do: nil

  def avatar_url(%__MODULE__{id: id, avatar: avatar}),
    do: "#{@discord_cdn}/avatars/#{id}/#{avatar}.png"

  def avatar_url(%{"avatar" => nil}), do: nil

  def avatar_url(%{"avatar" => a, "id" => id}) when is_binary(a),
    do: "#{@discord_cdn}/avatars/#{id}/#{a}.png"

  @doc """
  Returns the display name (global_name if set, otherwise username).

  Accepts both `%EDA.User{}` structs and raw maps (from cache).
  """
  @spec display_name(t() | map()) :: String.t() | nil
  def display_name(%__MODULE__{global_name: name}) when is_binary(name), do: name
  def display_name(%__MODULE__{username: name}), do: name
  def display_name(%{"global_name" => name}) when is_binary(name), do: name
  def display_name(%{"username" => name}), do: name

  @doc "Returns `true` if the user is a bot. Accepts structs and raw maps."
  @spec bot?(t() | map()) :: boolean()
  def bot?(%__MODULE__{bot: true}), do: true
  def bot?(%{"bot" => true}), do: true
  def bot?(_), do: false

  # ── Entity Manager ──

  use EDA.Entity

  @doc """
  Fetches a user by ID. Checks cache first, falls back to REST.
  """
  @spec fetch(t() | String.t() | integer()) :: {:ok, t()} | {:error, term()}
  def fetch(%__MODULE__{id: id}), do: fetch(id)

  def fetch(user_id) do
    case EDA.Cache.get_user(user_id) do
      nil -> EDA.API.User.get(user_id) |> parse_response()
      raw -> {:ok, from_raw(raw)}
    end
  end

  @doc """
  Fetches a user by ID. Raises on error.
  """
  @spec fetch!(t() | String.t() | integer()) :: t()
  def fetch!(user_id) do
    case fetch(user_id) do
      {:ok, user} -> user
      {:error, reason} -> raise "Failed to fetch user: #{inspect(reason)}"
    end
  end

  @doc """
  Creates a DM channel with a user. Returns a `%EDA.Channel{}` struct.
  """
  @spec create_dm(t() | String.t() | integer()) :: {:ok, EDA.Channel.t()} | {:error, term()}
  def create_dm(%__MODULE__{id: id}), do: create_dm(id)

  def create_dm(user_id) do
    case EDA.API.User.create_dm(user_id) do
      {:ok, raw} when is_map(raw) -> {:ok, EDA.Channel.from_raw(raw)}
      {:error, _} = err -> err
    end
  end
end
