defmodule EDA.Role do
  @moduledoc "Represents a Discord guild role."
  use EDA.Event.Access

  defstruct [
    :id,
    :name,
    :color,
    :colors,
    :hoist,
    :icon,
    :unicode_emoji,
    :position,
    :permissions,
    :managed,
    :mentionable,
    :tags,
    :flags
  ]

  @type t :: %__MODULE__{
          id: String.t() | nil,
          name: String.t() | nil,
          color: integer() | nil,
          colors: EDA.Role.Colors.t() | nil,
          hoist: boolean() | nil,
          icon: String.t() | nil,
          unicode_emoji: String.t() | nil,
          position: integer() | nil,
          permissions: String.t() | nil,
          managed: boolean() | nil,
          mentionable: boolean() | nil,
          tags: EDA.Role.Tags.t() | nil,
          flags: non_neg_integer() | nil
        }

  @spec from_raw(map()) :: t()
  def from_raw(raw) when is_map(raw) do
    %__MODULE__{
      id: raw["id"],
      name: raw["name"],
      color: raw["color"],
      colors: EDA.Role.Colors.from_raw(raw["colors"]),
      hoist: raw["hoist"],
      icon: raw["icon"],
      unicode_emoji: raw["unicode_emoji"],
      position: raw["position"],
      permissions: raw["permissions"],
      managed: raw["managed"],
      mentionable: raw["mentionable"],
      tags: EDA.Role.Tags.from_raw(raw["tags"]),
      flags: raw["flags"]
    }
  end

  @doc """
  The role's primary colour, preferring the newer `colors` object.

  Discord deprecated the single `color` field in favour of `colors`; on a real
  guild the two agreed, but `colors.primary_color` is the field to trust. Falls
  back to `color` when `colors` is absent.

  ## Examples

      iex> EDA.Role.primary_color(%EDA.Role{color: 1, colors: %EDA.Role.Colors{primary_color: 2}})
      2

      iex> EDA.Role.primary_color(%EDA.Role{color: 1})
      1
  """
  @spec primary_color(t()) :: integer() | nil
  def primary_color(%__MODULE__{colors: %EDA.Role.Colors{primary_color: c}}) when not is_nil(c),
    do: c

  def primary_color(%__MODULE__{color: color}), do: color

  @doc """
  The role's colour style: `:default`, `:solid`, `:gradient` or `:holographic`.

  A role with no colour of its own is `:default`, not `:solid` — 39% of roles on real
  guilds are in that state. See `EDA.Role.Colors`.

  ## Examples

      iex> EDA.Role.style(%EDA.Role{colors: %EDA.Role.Colors{primary_color: 1, secondary_color: 2}})
      :gradient

      iex> EDA.Role.style(%EDA.Role{colors: %EDA.Role.Colors{primary_color: 1}})
      :solid

      iex> EDA.Role.style(%EDA.Role{color: 1})
      :default
  """
  @spec style(t()) :: EDA.Role.Colors.style()
  def style(%__MODULE__{colors: colors}), do: EDA.Role.Colors.style(colors)

  @doc """
  Returns `true` when the role has no colour of its own.

  ## Examples

      iex> EDA.Role.default?(%EDA.Role{colors: %EDA.Role.Colors{primary_color: 0}})
      true

      iex> EDA.Role.default?(%EDA.Role{colors: %EDA.Role.Colors{primary_color: 1}})
      false
  """
  @spec default?(t()) :: boolean()
  def default?(%__MODULE__{colors: colors}), do: EDA.Role.Colors.default?(colors)

  @doc """
  Returns `true` when the role uses a two-colour gradient.

  **Not** true for holographic roles — use `holographic?/1` for those. Discord treats
  the two as distinct styles, as do JDA and discord.js.

  ## Examples

      iex> EDA.Role.gradient?(%EDA.Role{colors: %EDA.Role.Colors{primary_color: 1, secondary_color: 2}})
      true

      iex> EDA.Role.gradient?(%EDA.Role{colors: EDA.Role.Colors.holographic()})
      false

      iex> EDA.Role.gradient?(%EDA.Role{color: 1})
      false
  """
  @spec gradient?(t()) :: boolean()
  def gradient?(%__MODULE__{colors: colors}), do: EDA.Role.Colors.gradient?(colors)

  @doc """
  Returns `true` when the role uses the holographic style.

  ## Examples

      iex> EDA.Role.holographic?(%EDA.Role{colors: EDA.Role.Colors.holographic()})
      true

      iex> EDA.Role.holographic?(%EDA.Role{color: 1})
      false
  """
  @spec holographic?(t()) :: boolean()
  def holographic?(%__MODULE__{colors: colors}), do: EDA.Role.Colors.holographic?(colors)

  @doc """
  Sets this role's colours, returning the updated `%EDA.Role{}`.

  Accepts a role struct or a role ID, like `modify/4`.

  ## Options

  - `:reason` — audit log reason

  ## Examples

      EDA.Role.set_colors(guild_id, role, EDA.Role.Colors.gradient(0xFF0000, 0x00FF00))
      EDA.Role.set_colors(guild_id, role_id, EDA.Role.Colors.holographic())
  """
  @spec set_colors(
          String.t() | integer(),
          t() | String.t() | integer(),
          EDA.Role.Colors.t() | map(),
          keyword()
        ) :: {:ok, t()} | {:error, term()}
  def set_colors(guild_id, role, colors, opts \\ [])

  def set_colors(guild_id, %__MODULE__{id: id}, colors, opts),
    do: set_colors(guild_id, id, colors, opts)

  def set_colors(guild_id, role_id, colors, opts) do
    EDA.API.Role.set_colors(guild_id, role_id, colors, opts) |> parse_response()
  end

  @doc "Returns a mention string like `<@&id>`."
  @spec mention(t()) :: String.t()
  def mention(%__MODULE__{id: id}), do: "<@&#{id}>"

  @doc """
  The role's flags, from `flags`, as `EDA.Role.Flags` names them. Accepts a struct or a raw map,
  and gives `[]` when Discord sent none.

      iex> EDA.Role.flags(%EDA.Role{flags: 1})
      [:in_prompt]
  """
  @spec flags(t() | map()) :: [EDA.Role.Flags.flag()]
  def flags(%__MODULE__{flags: flags}), do: EDA.Role.Flags.to_list(flags)
  def flags(%{"flags" => flags}), do: EDA.Role.Flags.to_list(flags)
  def flags(_), do: []

  @doc """
  Whether `flags` carries a flag.

      iex> EDA.Role.flag?(%EDA.Role{flags: 1}, :in_prompt)
      true
  """
  @spec flag?(t() | map(), EDA.Role.Flags.flag()) :: boolean()
  def flag?(%__MODULE__{flags: flags}, flag), do: EDA.Role.Flags.has?(flags, flag)
  def flag?(%{"flags" => flags}, flag), do: EDA.Role.Flags.has?(flags, flag)
  def flag?(_, _flag), do: false

  # ── Entity Manager ──

  use EDA.Entity

  @doc """
  Fetches a role by guild ID and role ID. Checks cache first, falls back to REST.
  """
  @spec fetch_role(String.t() | integer(), String.t() | integer()) ::
          {:ok, t()} | {:error, term()}
  def fetch_role(guild_id, role_id) do
    case EDA.Cache.get_role(role_id) do
      nil -> fetch_from_rest(guild_id, role_id)
      raw -> {:ok, from_raw(raw)}
    end
  end

  defp fetch_from_rest(guild_id, role_id) do
    role_id_str = to_string(role_id)

    with {:ok, roles} <- EDA.API.Role.list(guild_id),
         raw when not is_nil(raw) <- Enum.find(roles, &(to_string(&1["id"]) == role_id_str)) do
      {:ok, from_raw(raw)}
    else
      nil -> {:error, :not_found}
      {:error, _} = err -> err
    end
  end

  @doc """
  Creates a role in a guild.

  ## Options

  - `:reason` - Audit log reason
  """
  @spec create(String.t() | integer(), keyword() | map(), keyword()) ::
          {:ok, t()} | {:error, term()}
  def create(guild_id, params \\ [], opts \\ []) do
    EDA.API.Role.create(guild_id, params, opts) |> parse_response()
  end

  @doc """
  Modifies a guild role.

  ## Options

  - `:reason` - Audit log reason
  """
  @spec modify(String.t() | integer(), t() | String.t() | integer(), map(), keyword()) ::
          {:ok, t()} | {:error, term()}
  def modify(guild_id, role, payload, opts \\ [])

  def modify(guild_id, %__MODULE__{id: id}, payload, opts),
    do: modify(guild_id, id, payload, opts)

  def modify(guild_id, role_id, payload, opts)
      when (is_binary(role_id) or is_integer(role_id)) and is_map(payload) do
    EDA.API.Role.modify(guild_id, role_id, payload, opts) |> parse_response()
  end

  @doc """
  Deletes a guild role.

  ## Options

  - `:reason` - Audit log reason
  """
  @spec delete(String.t() | integer(), t() | String.t() | integer(), keyword()) ::
          :ok | {:error, term()}
  def delete(guild_id, role, opts \\ [])
  def delete(guild_id, %__MODULE__{id: id}, opts), do: delete(guild_id, id, opts)

  def delete(guild_id, role_id, opts) when is_binary(role_id) or is_integer(role_id) do
    EDA.API.Role.delete(guild_id, role_id, opts)
  end

  @doc """
  Applies a changeset to a role. No-op if the changeset has no changes.

  Requires `guild_id` since roles are guild-scoped.

  ## Options

  - `:reason` - Audit log reason
  """
  @spec apply_changeset(String.t() | integer(), Changeset.t(), keyword()) ::
          {:ok, t()} | {:error, term()}
  def apply_changeset(guild_id, changeset, opts \\ [])

  def apply_changeset(guild_id, %Changeset{module: __MODULE__, entity: entity} = cs, opts) do
    if Changeset.changed?(cs) do
      modify(guild_id, entity, Changeset.changes(cs), opts)
    else
      {:ok, entity}
    end
  end
end
