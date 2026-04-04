defmodule EDA.Guild do
  @moduledoc "Represents a Discord guild."
  use EDA.Event.Access

  defstruct [
    :id,
    :name,
    :owner_id,
    :icon,
    :channels,
    :members,
    :roles,
    :voice_states,
    :presences,
    :member_count,
    :large,
    :unavailable
  ]

  @type t :: %__MODULE__{
          id: String.t() | nil,
          name: String.t() | nil,
          owner_id: String.t() | nil,
          icon: String.t() | nil,
          channels: [EDA.Channel.t()] | nil,
          members: [EDA.Member.t()] | nil,
          roles: [EDA.Role.t()] | nil,
          voice_states: [map()] | nil,
          presences: [map()] | nil,
          member_count: integer() | nil,
          large: boolean() | nil,
          unavailable: boolean() | nil
        }

  @spec from_raw(map()) :: t()
  def from_raw(raw) when is_map(raw) do
    %__MODULE__{
      id: raw["id"],
      name: raw["name"],
      owner_id: raw["owner_id"],
      icon: raw["icon"],
      channels: parse_channels(raw["channels"]),
      members: parse_members(raw["members"]),
      roles: parse_roles(raw["roles"]),
      voice_states: raw["voice_states"],
      presences: raw["presences"],
      member_count: raw["member_count"],
      large: raw["large"],
      unavailable: raw["unavailable"]
    }
  end

  defp parse_channels(nil), do: nil
  defp parse_channels(list) when is_list(list), do: Enum.map(list, &EDA.Channel.from_raw/1)

  defp parse_members(nil), do: nil
  defp parse_members(list) when is_list(list), do: Enum.map(list, &EDA.Member.from_raw/1)

  defp parse_roles(nil), do: nil
  defp parse_roles(list) when is_list(list), do: Enum.map(list, &EDA.Role.from_raw/1)

  # ── Entity Manager ──

  use EDA.Entity

  @doc """
  Fetches a guild by ID. Checks cache first, falls back to REST.

  Accepts a guild struct or a string/integer ID.
  """
  @spec fetch(t() | String.t() | integer()) :: {:ok, t()} | {:error, term()}
  def fetch(%__MODULE__{id: id}), do: fetch(id)

  def fetch(guild_id) do
    case EDA.Cache.get_guild(guild_id) do
      nil -> EDA.API.Guild.get(guild_id) |> parse_response()
      raw -> {:ok, from_raw(raw)}
    end
  end

  @doc """
  Fetches a guild by ID. Raises on error.
  """
  @spec fetch!(t() | String.t() | integer()) :: t()
  def fetch!(guild_id) do
    case fetch(guild_id) do
      {:ok, guild} -> guild
      {:error, reason} -> raise "Failed to fetch guild: #{inspect(reason)}"
    end
  end

  @doc """
  Modifies a guild. Accepts a struct or ID, a map of changes, and options.

  ## Options

  - `:reason` - Audit log reason
  """
  @spec modify(t() | String.t() | integer(), map(), keyword()) :: {:ok, t()} | {:error, term()}
  def modify(guild, payload, opts \\ [])
  def modify(%__MODULE__{id: id}, payload, opts), do: modify(id, payload, opts)

  def modify(guild_id, payload, opts) when is_binary(guild_id) or is_integer(guild_id) do
    EDA.API.Guild.modify(guild_id, payload, opts) |> parse_response()
  end

  @doc """
  Applies a changeset to a guild. No-op if the changeset has no changes.

  ## Options

  - `:reason` - Audit log reason
  """
  @spec apply_changeset(Changeset.t(), keyword()) :: {:ok, t()} | {:error, term()}
  def apply_changeset(changeset, opts \\ [])

  def apply_changeset(%Changeset{module: __MODULE__, entity: entity} = cs, opts) do
    if Changeset.changed?(cs) do
      modify(entity, Changeset.changes(cs), opts)
    else
      {:ok, entity}
    end
  end

  @doc """
  Deletes a guild. The bot must be the owner.
  """
  @spec delete(t() | String.t() | integer()) :: :ok | {:error, term()}
  def delete(%__MODULE__{id: id}), do: delete(id)

  def delete(guild_id) do
    EDA.HTTP.Client.delete("/guilds/#{guild_id}") |> parse_response()
  end

  @doc """
  Gets channels for a guild, returned as `%EDA.Channel{}` structs.
  """
  @spec channels(t() | String.t() | integer()) :: {:ok, [EDA.Channel.t()]} | {:error, term()}
  def channels(%__MODULE__{id: id}), do: channels(id)

  def channels(guild_id) do
    case EDA.API.Guild.channels(guild_id) do
      {:ok, list} -> {:ok, Enum.map(list, &EDA.Channel.from_raw/1)}
      {:error, _} = err -> err
    end
  end

  @discord_cdn "https://cdn.discordapp.com"

  @doc """
  Returns the CDN URL for the guild's icon, or `nil` if the guild has no icon.

  ## Examples

      EDA.Guild.icon_url(guild)
      #=> "https://cdn.discordapp.com/icons/123/abc.png"
  """
  @spec icon_url(t()) :: String.t() | nil
  def icon_url(%__MODULE__{icon: nil}), do: nil
  def icon_url(%__MODULE__{id: id, icon: icon}), do: "#{@discord_cdn}/icons/#{id}/#{icon}.png"
end
