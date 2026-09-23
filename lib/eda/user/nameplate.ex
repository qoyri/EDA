defmodule EDA.User.Nameplate do
  @moduledoc """
  The plate drawn behind a user's name in the member list.

  Part of `collectibles`. `asset` is a path inside the collectibles bucket and already ends with
  a slash, so `url/2` only appends the file name.

  ## Example

      %EDA.User.Nameplate{
        asset: "nameplates/zodiac/virgo/",
        sku_id: "1447654091097509950",
        label: "COLLECTIBLES_ZODIAC_VIRGO_NP_A11Y",
        palette: "lemon"
      }

  `label` is a localisation key for screen readers, not text to show. `palette` names the
  background colour Discord pairs with the plate.
  """

  use EDA.Event.Access

  @discord_cdn "https://cdn.discordapp.com"

  defstruct [:asset, :sku_id, :label, :palette]

  @type t :: %__MODULE__{
          asset: String.t() | nil,
          sku_id: String.t() | nil,
          label: String.t() | nil,
          palette: String.t() | nil
        }

  @doc "Parses the raw `nameplate` object. Returns `nil` when absent or null."
  @spec from_raw(map() | nil) :: t() | nil
  def from_raw(nil), do: nil

  def from_raw(%__MODULE__{} = parsed), do: parsed

  def from_raw(raw) when is_map(raw) do
    %__MODULE__{
      asset: :maps.get("asset", raw, nil),
      sku_id: :maps.get("sku_id", raw, nil),
      label: :maps.get("label", raw, nil),
      palette: :maps.get("palette", raw, nil)
    }
  end

  def from_raw(_), do: nil

  @doc """
  URL of the plate, or `nil` when there is none.

  Discord serves two files per plate, and neither is in its CDN endpoints table; both were
  checked against a live plate. `:animated` is the WebM the client plays, `:static` the PNG
  still — the one to use wherever a video cannot go, such as an embed image.

  ## Options

  - `:format` — `:animated` (default, `.webm`) or `:static` (`.png`)

  ## Examples

      iex> EDA.User.Nameplate.url(%EDA.User.Nameplate{asset: "nameplates/zodiac/virgo/"})
      "https://cdn.discordapp.com/assets/collectibles/nameplates/zodiac/virgo/asset.webm"

      iex> EDA.User.Nameplate.url(%EDA.User.Nameplate{asset: "nameplates/zodiac/virgo/"}, format: :static)
      "https://cdn.discordapp.com/assets/collectibles/nameplates/zodiac/virgo/static.png"

      iex> EDA.User.Nameplate.url(nil)
      nil
  """
  @spec url(t() | nil, keyword()) :: String.t() | nil
  def url(nameplate, opts \\ [])

  def url(%__MODULE__{asset: asset}, opts) when is_binary(asset) do
    "#{@discord_cdn}/assets/collectibles/#{asset}#{file_name!(opts[:format] || :animated)}"
  end

  def url(_nameplate, _opts), do: nil

  defp file_name!(:animated), do: "asset.webm"
  defp file_name!(:static), do: "static.png"

  defp file_name!(other),
    do: raise(ArgumentError, "a nameplate is :animated or :static, got #{inspect(other)}")
end
