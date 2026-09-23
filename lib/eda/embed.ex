defmodule EDA.Embed do
  @moduledoc """
  Builder for Discord embed objects.

  Provides a pipe-friendly API for constructing embeds with eager validation
  against Discord's limits.

  ## Example

      import EDA.Embed

      embed =
        new()
        |> title("My Embed")
        |> description("A cool description")
        |> color(:blurple)
        |> url("https://example.com")
        |> timestamp(DateTime.utc_now())
        |> footer("Footer text", icon_url: "https://example.com/icon.png")
        |> author("Author Name", url: "https://example.com", icon_url: "https://example.com/avatar.png")
        |> thumbnail("https://example.com/thumb.png")
        |> image("https://example.com/image.png")
        |> field("Name", "Value")
        |> field("Inline Field", "Value", inline: true)

      EDA.API.Message.create(channel_id, embed: embed)

  ## Received embeds

  An embed on a received message is the same struct, down to its parts: `EDA.Embed.Footer`,
  `EDA.Embed.Author`, `EDA.Embed.Field`, `EDA.Embed.Media` for the image, thumbnail and video,
  and `EDA.Embed.Provider` for the site a link embed comes from. `timestamp` is a `DateTime`,
  and `type` is `:rich` for an embed a bot built, or `:image`, `:video`, `:gifv`, `:article`,
  `:link` or `:poll_result` for one Discord made; a type added later stays its string.

  A received embed can be sent again as is: `to_map/1` leaves out what only Discord sets (the
  type, the proxied URLs, the sizes, the video and the provider).
  """

  use EDA.Event.Access

  alias EDA.Embed.{Author, Field, Footer, Media, Provider}

  @enforce_keys []
  defstruct [
    :title,
    :type,
    :description,
    :url,
    :timestamp,
    :color,
    :footer,
    :image,
    :thumbnail,
    :video,
    :provider,
    :author,
    :flags,
    fields: []
  ]

  @type type :: :rich | :image | :video | :gifv | :article | :link | :poll_result | String.t()

  @type t :: %__MODULE__{
          title: String.t() | nil,
          type: type() | nil,
          description: String.t() | nil,
          url: String.t() | nil,
          timestamp: DateTime.t() | nil,
          color: non_neg_integer() | nil,
          footer: Footer.t() | nil,
          image: Media.t() | nil,
          thumbnail: Media.t() | nil,
          video: Media.t() | nil,
          provider: Provider.t() | nil,
          author: Author.t() | nil,
          flags: non_neg_integer() | nil,
          fields: [Field.t()]
        }

  @types Map.new(~w(rich image video gifv article link poll_result)a, &{Atom.to_string(&1), &1})

  @colors %{
    blurple: 0x5865F2,
    red: 0xED4245,
    green: 0x57F287,
    blue: 0x3498DB,
    yellow: 0xFEE75C,
    fuchsia: 0xEB459E,
    orange: 0xE67E22,
    purple: 0x9B59B6,
    gold: 0xF1C40F,
    teal: 0x1ABC9C,
    dark_red: 0x992D22,
    dark_blue: 0x206694,
    dark_green: 0x1F8B4C,
    dark_purple: 0x71368A,
    dark_gold: 0xC27C0E,
    dark_teal: 0x11806A,
    dark_theme: 0x2C2F33,
    greyple: 0x99AAB5,
    white: 0xFFFFFF,
    black: 0x000000,
    light_grey: 0x979C9F,
    dark_grey: 0x546E7A
  }

  # ── Constructor ─────────────────────────────────────────────────────

  @doc "Creates a new empty embed."
  @spec new() :: t()
  def new, do: %__MODULE__{}

  @doc """
  Creates a red error embed with the given text as description.

  Returns a pipeable embed struct — add fields, footer, etc. as needed.

  ## Examples

      EDA.Embed.error("Something went wrong")
      EDA.Embed.error("Not found") |> EDA.Embed.footer("Try again later")
  """
  @spec error(String.t()) :: t()
  def error(text) when is_binary(text) do
    new() |> color(:red) |> description(text)
  end

  @doc """
  Creates a green success embed with the given text as description.

  Returns a pipeable embed struct — add fields, footer, etc. as needed.

  ## Examples

      EDA.Embed.success("User banned successfully")
      EDA.Embed.success("Done!") |> EDA.Embed.title("Operation Complete")
  """
  @spec success(String.t()) :: t()
  def success(text) when is_binary(text) do
    new() |> color(:green) |> description(text)
  end

  @doc """
  An embed as Discord sends it, down to its parts.

      iex> embed = EDA.Embed.from_raw(%{"type" => "rich", "title" => "Hi", "footer" => %{"text" => "bye"}})
      iex> {embed.type, embed.title, embed.footer.text}
      {:rich, "Hi", "bye"}
  """
  @spec from_raw(map()) :: t()
  def from_raw(raw) when is_map(raw) do
    %__MODULE__{
      title: raw["title"],
      type: Map.get(@types, raw["type"], raw["type"]),
      description: raw["description"],
      url: raw["url"],
      timestamp: EDA.Timestamp.parse(raw["timestamp"]),
      color: raw["color"],
      footer: Footer.from_raw(raw["footer"]),
      image: Media.from_raw(raw["image"]),
      thumbnail: Media.from_raw(raw["thumbnail"]),
      video: Media.from_raw(raw["video"]),
      provider: Provider.from_raw(raw["provider"]),
      author: Author.from_raw(raw["author"]),
      flags: raw["flags"],
      fields: Enum.map(raw["fields"] || [], &Field.from_raw/1)
    }
  end

  # ── Setters ─────────────────────────────────────────────────────────

  @doc "Sets the embed title (max 256 characters)."
  @spec title(t(), String.t()) :: t()
  def title(%__MODULE__{} = embed, text) when is_binary(text) do
    validate_length!(text, 256, "title")
    %{embed | title: text}
  end

  @doc "Sets the embed description (max 4096 characters)."
  @spec description(t(), String.t()) :: t()
  def description(%__MODULE__{} = embed, text) when is_binary(text) do
    validate_length!(text, 4096, "description")
    %{embed | description: text}
  end

  @doc "Sets the embed URL."
  @spec url(t(), String.t()) :: t()
  def url(%__MODULE__{} = embed, url) when is_binary(url) do
    %{embed | url: url}
  end

  @doc """
  Sets the embed timestamp.

  Accepts a `DateTime`, a `NaiveDateTime` (taken as UTC), or an ISO 8601 string, and stores a
  `DateTime`.
  """
  @spec timestamp(t(), DateTime.t() | NaiveDateTime.t() | String.t()) :: t()
  def timestamp(%__MODULE__{} = embed, %DateTime{} = dt) do
    %{embed | timestamp: dt}
  end

  def timestamp(%__MODULE__{} = embed, %NaiveDateTime{} = ndt) do
    %{embed | timestamp: DateTime.from_naive!(ndt, "Etc/UTC")}
  end

  def timestamp(%__MODULE__{} = embed, ts) when is_binary(ts) do
    case EDA.Timestamp.parse(ts) do
      %DateTime{} = dt -> %{embed | timestamp: dt}
      nil -> raise ArgumentError, "invalid ISO 8601 timestamp: #{inspect(ts)}"
    end
  end

  @doc """
  Sets the embed color.

  Accepts an integer (0..0xFFFFFF), a color atom (`:blurple`, `:red`, etc.),
  or a hex string (`"#FF0000"`, `"#F00"`, `"FF0000"`).
  """
  @spec color(t(), non_neg_integer() | atom() | String.t()) :: t()
  def color(%__MODULE__{} = embed, value) when is_integer(value) do
    if value < 0 or value > 0xFFFFFF do
      raise ArgumentError, "color must be between 0 and 0xFFFFFF, got: #{value}"
    end

    %{embed | color: value}
  end

  def color(%__MODULE__{} = embed, :random) do
    %{embed | color: EDA.Color.random()}
  end

  def color(%__MODULE__{} = embed, name) when is_atom(name) do
    case Map.fetch(@colors, name) do
      {:ok, value} ->
        %{embed | color: value}

      :error ->
        valid = @colors |> Map.keys() |> Enum.sort() |> Enum.join(", ")
        raise ArgumentError, "unknown color #{inspect(name)}, valid colors: #{valid}"
    end
  end

  def color(%__MODULE__{} = embed, hex) when is_binary(hex) do
    %{embed | color: parse_hex_color!(hex)}
  end

  @doc """
  Sets the embed footer.

  ## Options

    * `:icon_url` - URL of footer icon
  """
  @spec footer(t(), String.t(), keyword()) :: t()
  def footer(%__MODULE__{} = embed, text, opts \\ []) when is_binary(text) do
    validate_length!(text, 2048, "footer text")

    %{embed | footer: %Footer{text: text, icon_url: opts[:icon_url]}}
  end

  @doc """
  Sets the embed author.

  ## Options

    * `:url` - URL of the author
    * `:icon_url` - URL of author icon
  """
  @spec author(t(), String.t(), keyword()) :: t()
  def author(%__MODULE__{} = embed, name, opts \\ []) when is_binary(name) do
    validate_length!(name, 256, "author name")

    %{embed | author: %Author{name: name, url: opts[:url], icon_url: opts[:icon_url]}}
  end

  @doc "Sets the embed thumbnail URL."
  @spec thumbnail(t(), String.t()) :: t()
  def thumbnail(%__MODULE__{} = embed, url) when is_binary(url) do
    %{embed | thumbnail: %Media{url: url}}
  end

  @doc "Sets the embed image URL."
  @spec image(t(), String.t()) :: t()
  def image(%__MODULE__{} = embed, url) when is_binary(url) do
    %{embed | image: %Media{url: url}}
  end

  @doc """
  Adds a field to the embed (max 25 fields).

  ## Options

    * `:inline` - Whether the field should be inline (default: `false`)
  """
  @spec field(t(), String.t(), String.t(), keyword()) :: t()
  def field(%__MODULE__{} = embed, name, value, opts \\ [])
      when is_binary(name) and is_binary(value) do
    if length(embed.fields) >= 25 do
      raise ArgumentError, "embed cannot have more than 25 fields"
    end

    validate_length!(name, 256, "field name")
    validate_length!(value, 1024, "field value")

    f = %Field{name: name, value: value, inline: Keyword.get(opts, :inline, false)}
    %{embed | fields: embed.fields ++ [f]}
  end

  # ── Validation ──────────────────────────────────────────────────────

  @doc """
  Validates the aggregate 6000-character total limit across all text content.

  Returns `{:ok, embed}` or `{:error, reasons}`.
  """
  @spec validate(t()) :: {:ok, t()} | {:error, [String.t()]}
  def validate(%__MODULE__{} = embed) do
    total = total_chars(embed)
    errors = []

    errors =
      if total > 6000 do
        ["total character count #{total} exceeds 6000 limit" | errors]
      else
        errors
      end

    case errors do
      [] -> {:ok, embed}
      list -> {:error, Enum.reverse(list)}
    end
  end

  @doc """
  Like `validate/1`, but raises on failure.
  """
  @spec validate!(t()) :: t()
  def validate!(%__MODULE__{} = embed) do
    case validate(embed) do
      {:ok, embed} -> embed
      {:error, reasons} -> raise ArgumentError, Enum.join(reasons, "; ")
    end
  end

  # ── Serialization ───────────────────────────────────────────────────

  @doc """
  Converts the embed struct to the map Discord takes, leaving out empty values and what only
  Discord sets.
  """
  @spec to_map(t()) :: map()
  def to_map(%__MODULE__{} = embed) do
    %{
      title: embed.title,
      description: embed.description,
      url: embed.url,
      timestamp: embed.timestamp && DateTime.to_iso8601(embed.timestamp),
      color: embed.color,
      footer: embed.footer && %{text: embed.footer.text, icon_url: embed.footer.icon_url},
      image: embed.image && %{url: embed.image.url},
      thumbnail: embed.thumbnail && %{url: embed.thumbnail.url},
      author:
        embed.author &&
          %{name: embed.author.name, url: embed.author.url, icon_url: embed.author.icon_url},
      fields:
        if(embed.fields != [],
          do: Enum.map(embed.fields, &%{name: &1.name, value: &1.value, inline: &1.inline})
        )
    }
    |> strip_nils()
  end

  # ── Private ─────────────────────────────────────────────────────────

  defp validate_length!(text, max, label) do
    len = String.length(text)

    if len > max do
      raise ArgumentError, "#{label} must be at most #{max} characters, got #{len}"
    end
  end

  defp parse_hex_color!(hex) do
    hex = String.trim_leading(hex, "#")

    hex =
      case String.length(hex) do
        3 ->
          hex
          |> String.graphemes()
          |> Enum.map_join(&(&1 <> &1))

        6 ->
          hex

        _ ->
          raise ArgumentError,
                "invalid hex color #{inspect("#" <> hex)}, expected 3 or 6 hex digits"
      end

    case Integer.parse(hex, 16) do
      {value, ""} when value >= 0 and value <= 0xFFFFFF ->
        value

      _ ->
        raise ArgumentError, "invalid hex color #{inspect("#" <> hex)}"
    end
  end

  defp strip_nils(map) when is_map(map) do
    map
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Enum.map(fn {k, v} -> {k, strip_nils(v)} end)
    |> Map.new()
  end

  defp strip_nils(list) when is_list(list), do: Enum.map(list, &strip_nils/1)
  defp strip_nils(value), do: value

  defp total_chars(%__MODULE__{} = embed) do
    safe_len(embed.title) +
      safe_len(embed.description) +
      safe_len(embed.footer && embed.footer[:text]) +
      safe_len(embed.author && embed.author[:name]) +
      Enum.reduce(embed.fields, 0, fn f, acc ->
        acc + safe_len(f[:name]) + safe_len(f[:value])
      end)
  end

  defp safe_len(nil), do: 0
  defp safe_len(text) when is_binary(text), do: String.length(text)
end

defimpl Jason.Encoder, for: EDA.Embed do
  def encode(embed, opts) do
    embed
    |> EDA.Embed.to_map()
    |> Jason.Encode.map(opts)
  end
end
