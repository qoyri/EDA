defmodule EDA.Color do
  @moduledoc """
  Discord embed and component color utilities.

  Provides named color constants, hex parsing, and cryptographically random
  color generation for embeds and components.

  ## Named colors

      EDA.Color.blurple()   #=> 0x5865F2
      EDA.Color.red()       #=> 0xED4245
      EDA.Color.random()    #=> 0xA3F29C  (different every call)

  ## Usage with embeds

      import EDA.Embed

      new()
      |> color(:random)
      |> title("Every embed gets a unique color")

  ## Usage with components (V2 containers)

      import EDA.Component

      container([...], color: EDA.Color.random())
  """

  @named %{
    # Discord brand
    blurple: 0x5865F2,
    fuchsia: 0xEB459E,
    greyple: 0x99AAB5,
    dark_theme: 0x2C2F33,
    # Standard
    red: 0xED4245,
    green: 0x57F287,
    blue: 0x3498DB,
    yellow: 0xFEE75C,
    orange: 0xE67E22,
    purple: 0x9B59B6,
    gold: 0xF1C40F,
    teal: 0x1ABC9C,
    white: 0xFFFFFF,
    black: 0x000000,
    # Dark variants
    dark_red: 0x992D22,
    dark_blue: 0x206694,
    dark_green: 0x1F8B4C,
    dark_purple: 0x71368A,
    dark_gold: 0xC27C0E,
    dark_teal: 0x11806A,
    # Greys
    light_grey: 0x979C9F,
    dark_grey: 0x546E7A,
    # Extras
    pink: 0xFF69B4,
    cyan: 0x00FFFF,
    lime: 0x2ECC71,
    indigo: 0x4B0082,
    coral: 0xFF7F50,
    salmon: 0xFA8072,
    mint: 0x98FF98,
    lavender: 0xE6E6FA
  }

  @doc """
  Returns a cryptographically random color (0x000000..0xFFFFFF).

  Uses `:crypto.strong_rand_bytes/1` for uniform distribution — every color
  in the 16.7M range has equal probability. No repeating patterns.

  ## Examples

      EDA.Color.random()  #=> 0xA3F29C
      EDA.Color.random()  #=> 0x1B44E7
  """
  @spec random() :: non_neg_integer()
  def random do
    <<r, g, b>> = :crypto.strong_rand_bytes(3)
    Bitwise.bsl(r, 16) + Bitwise.bsl(g, 8) + b
  end

  @doc """
  Resolves a color value from a name atom, integer, hex string, or `:random`.

  ## Examples

      EDA.Color.resolve(:blurple)   #=> 0x5865F2
      EDA.Color.resolve(:random)    #=> 0x...... (random)
      EDA.Color.resolve(0xFF0000)   #=> 0xFF0000
      EDA.Color.resolve("#FF0000")  #=> 0xFF0000
  """
  @spec resolve(atom() | non_neg_integer() | String.t()) :: non_neg_integer()
  def resolve(:random), do: random()

  def resolve(name) when is_atom(name) do
    case Map.fetch(@named, name) do
      {:ok, value} ->
        value

      :error ->
        raise ArgumentError,
              "unknown color #{inspect(name)}, use EDA.Color.all_names() to see available colors"
    end
  end

  def resolve(value) when is_integer(value) and value >= 0 and value <= 0xFFFFFF, do: value

  def resolve(hex) when is_binary(hex), do: parse_hex!(hex)

  @doc "Returns a map of all named colors."
  @spec all() :: %{atom() => non_neg_integer()}
  def all, do: @named

  @doc "Returns a sorted list of all named color atoms."
  @spec all_names() :: [atom()]
  def all_names, do: @named |> Map.keys() |> Enum.sort()

  # Generate a function for each named color
  for {name, value} <- @named do
    @doc "Returns the `#{name}` color value (`0x#{Integer.to_string(value, 16)}`)."
    @spec unquote(name)() :: non_neg_integer()
    def unquote(name)(), do: unquote(value)
  end

  defp parse_hex!(hex) do
    hex = String.trim_leading(hex, "#")

    hex =
      case String.length(hex) do
        3 ->
          hex |> String.graphemes() |> Enum.map_join(&(&1 <> &1))

        6 ->
          hex

        _ ->
          raise ArgumentError,
                "invalid hex color #{inspect("#" <> hex)}, expected 3 or 6 hex digits"
      end

    case Integer.parse(hex, 16) do
      {value, ""} when value >= 0 and value <= 0xFFFFFF -> value
      _ -> raise ArgumentError, "invalid hex color #{inspect("#" <> hex)}"
    end
  end
end
