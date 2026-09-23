defmodule EDA.Role.Colors do
  @moduledoc """
  A role's colours: solid, gradient, or holographic.

  Supersedes the role's single `color` field, which Discord deprecated — JDA marks
  its equivalent `getColor()` as `@ReplaceWith("getColors().getPrimary()")`, and
  discord.js sends only `colors` when editing a role, never `color`.

  ## Four styles

  `style/1` returns `:default`, `:solid`, `:gradient` or `:holographic`, mirroring JDA's
  `isDefault()` / `isSolid()` / `isGradient()` / `isHolographic()`. Two distinctions matter:

    * `:default` — **no colour at all**. Discord represents this as `primary_color: 0`, which
      is not the same as an explicitly chosen black. Measured across 201 roles on 8 real
      guilds, **78 were in this state** — 39%, and only 8 of those were `@everyone`. Treating
      them as solid would mis-colour most of a typical guild's roles;
    * `:solid` — a real single colour;
    * `:gradient` — `secondary_color` is set, `tertiary_color` is not;
    * `:holographic` — `tertiary_color` is set, and **Discord then forces all three
      values** to `#{11_127_295}`, `#{16_759_788}`, `#{16_761_760}`. You cannot pick
      your own holographic colours. Use `holographic/0` rather than writing them out.

  ## Reading

      role.colors
      #=> %EDA.Role.Colors{primary_color: 10382335, secondary_color: 12427263, tertiary_color: nil}

      EDA.Role.Colors.style(role.colors)  #=> :gradient

  ## Writing

      EDA.Role.set_colors(guild_id, role_id, EDA.Role.Colors.gradient(0xFF0000, 0x00FF00))
      EDA.Role.set_colors(guild_id, role_id, EDA.Role.Colors.holographic())
      EDA.Role.set_colors(guild_id, role_id, EDA.Role.Colors.solid(0x5865F2))

  > #### Writing needs an eligible guild {: .warning}
  >
  > Setting a gradient or holographic colour on an ineligible guild fails with HTTP 403,
  > code **670006 "Missing guild feature"** (`EDA.Error.missing_guild_feature/0`). The
  > relevant feature is not advertised: `ENHANCED_ROLE_COLORS` appeared in **no** guild's
  > `features` array, including one with seven gradient roles already in place. So there is
  > no reliable pre-check — attempt the write and handle the error. Reading is unaffected.

  ## Observed behaviour

  Probed against a real guild (2026-09-19): every role carried all three keys,
  `primary_color` equalled the legacy `color` on all 57 roles, and 7 used a gradient.
  The `ENHANCED_ROLE_COLORS` guild feature was **absent** despite gradients being in
  use, so do not gate reads on that feature.
  """

  use EDA.Event.Access

  @holographic_primary 11_127_295
  @holographic_secondary 16_759_788
  @holographic_tertiary 16_761_760

  defstruct [:primary_color, :secondary_color, :tertiary_color]

  @type t :: %__MODULE__{
          primary_color: integer() | nil,
          secondary_color: integer() | nil,
          tertiary_color: integer() | nil
        }

  @typedoc "The colour style of a role."
  @type style :: :default | :solid | :gradient | :holographic

  # ── Parsing ──

  @doc "Parses the raw `colors` object. Returns `nil` when absent."
  @spec from_raw(map() | nil) :: t() | nil
  def from_raw(nil), do: nil

  def from_raw(%__MODULE__{} = parsed), do: parsed

  def from_raw(raw) when is_map(raw) do
    %__MODULE__{
      primary_color: :maps.get("primary_color", raw, nil),
      secondary_color: :maps.get("secondary_color", raw, nil),
      tertiary_color: :maps.get("tertiary_color", raw, nil)
    }
  end

  def from_raw(_), do: nil

  # ── Constructors ──

  @doc """
  A solid, single-colour role.

  ## Examples

      iex> EDA.Role.Colors.solid(0x5865F2)
      %EDA.Role.Colors{primary_color: 5793266, secondary_color: nil, tertiary_color: nil}
  """
  @spec solid(integer()) :: t()
  def solid(primary) when is_integer(primary), do: %__MODULE__{primary_color: primary}

  @doc """
  A two-colour gradient.

  ## Examples

      iex> EDA.Role.Colors.gradient(0xFF0000, 0x00FF00)
      %EDA.Role.Colors{primary_color: 16711680, secondary_color: 65280, tertiary_color: nil}
  """
  @spec gradient(integer(), integer()) :: t()
  def gradient(primary, secondary) when is_integer(primary) and is_integer(secondary) do
    %__MODULE__{primary_color: primary, secondary_color: secondary}
  end

  @doc """
  The holographic style, with the three values Discord enforces.

  Discord ignores any other values once `tertiary_color` is sent, so this takes no
  arguments on purpose.

  ## Examples

      iex> EDA.Role.Colors.holographic()
      %EDA.Role.Colors{primary_color: 11127295, secondary_color: 16759788, tertiary_color: 16761760}
  """
  @spec holographic() :: t()
  def holographic do
    %__MODULE__{
      primary_color: @holographic_primary,
      secondary_color: @holographic_secondary,
      tertiary_color: @holographic_tertiary
    }
  end

  @doc "The `primary_color` Discord enforces for holographic roles."
  @spec holographic_primary() :: integer()
  def holographic_primary, do: @holographic_primary

  @doc "The `secondary_color` Discord enforces for holographic roles."
  @spec holographic_secondary() :: integer()
  def holographic_secondary, do: @holographic_secondary

  @doc "The `tertiary_color` Discord enforces for holographic roles."
  @spec holographic_tertiary() :: integer()
  def holographic_tertiary, do: @holographic_tertiary

  # ── Style ──

  @doc """
  Returns the colour style: `:default`, `:solid`, `:gradient` or `:holographic`.

  `primary_color: 0` means *no colour*, not black — it is `:default`, as in JDA.

  ## Examples

      iex> EDA.Role.Colors.style(%EDA.Role.Colors{primary_color: 1})
      :solid

      iex> EDA.Role.Colors.style(%EDA.Role.Colors{primary_color: 0})
      :default

      iex> EDA.Role.Colors.style(%EDA.Role.Colors{primary_color: 1, secondary_color: 2})
      :gradient

      iex> EDA.Role.Colors.style(EDA.Role.Colors.holographic())
      :holographic

      iex> EDA.Role.Colors.style(nil)
      :default
  """
  @spec style(t() | nil) :: style()
  def style(%__MODULE__{tertiary_color: t}) when not is_nil(t), do: :holographic
  def style(%__MODULE__{secondary_color: s}) when not is_nil(s), do: :gradient
  def style(%__MODULE__{primary_color: p}) when p in [nil, 0], do: :default
  def style(%__MODULE__{}), do: :solid
  def style(nil), do: :default

  @doc """
  Returns `true` when the role has no colour of its own.

  ## Examples

      iex> EDA.Role.Colors.default?(%EDA.Role.Colors{primary_color: 0})
      true

      iex> EDA.Role.Colors.default?(%EDA.Role.Colors{primary_color: 1})
      false

      iex> EDA.Role.Colors.default?(nil)
      true
  """
  @spec default?(t() | nil) :: boolean()
  def default?(colors), do: style(colors) == :default

  @doc """
  Returns `true` for a role with one real colour — **not** for an uncoloured role.

  ## Examples

      iex> EDA.Role.Colors.solid?(%EDA.Role.Colors{primary_color: 1})
      true

      iex> EDA.Role.Colors.solid?(%EDA.Role.Colors{primary_color: 0})
      false

      iex> EDA.Role.Colors.solid?(EDA.Role.Colors.holographic())
      false
  """
  @spec solid?(t() | nil) :: boolean()
  def solid?(colors), do: style(colors) == :solid

  @doc """
  Returns `true` for a two-colour gradient — **not** for holographic roles.

  ## Examples

      iex> EDA.Role.Colors.gradient?(%EDA.Role.Colors{primary_color: 1, secondary_color: 2})
      true

      iex> EDA.Role.Colors.gradient?(EDA.Role.Colors.holographic())
      false

      iex> EDA.Role.Colors.gradient?(nil)
      false
  """
  @spec gradient?(t() | nil) :: boolean()
  def gradient?(colors), do: style(colors) == :gradient

  @doc """
  Returns `true` for the holographic style.

  ## Examples

      iex> EDA.Role.Colors.holographic?(EDA.Role.Colors.holographic())
      true

      iex> EDA.Role.Colors.holographic?(%EDA.Role.Colors{primary_color: 1, secondary_color: 2})
      false
  """
  @spec holographic?(t() | nil) :: boolean()
  def holographic?(colors), do: style(colors) == :holographic

  # ── Serialisation ──

  @doc """
  Converts to the snake_case object Discord expects in a role payload.

  Keys whose value is `nil` are omitted rather than sent as null, so a solid colour
  does not clear a gradient by accident.

  ## Examples

      iex> EDA.Role.Colors.to_map(EDA.Role.Colors.solid(255))
      %{primary_color: 255}

      iex> EDA.Role.Colors.to_map(EDA.Role.Colors.gradient(1, 2))
      %{primary_color: 1, secondary_color: 2}
  """
  @spec to_map(t()) :: map()
  def to_map(%__MODULE__{} = colors) do
    %{
      primary_color: colors.primary_color,
      secondary_color: colors.secondary_color,
      tertiary_color: colors.tertiary_color
    }
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Map.new()
  end
end

defimpl Jason.Encoder, for: EDA.Role.Colors do
  def encode(colors, opts) do
    colors
    |> EDA.Role.Colors.to_map()
    |> Jason.Encode.map(opts)
  end
end
