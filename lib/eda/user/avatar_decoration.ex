defmodule EDA.User.AvatarDecoration do
  @moduledoc """
  The frame drawn around a user's avatar.

  Present on a user and on a guild member, and `nil` for anyone without one.

  `expires_at` is not in Discord's documentation of the object, but it is sent: a decoration
  from a limited-time collection stops being shown after it. It is `nil` for a permanent one.

  ## Example

      %EDA.User.AvatarDecoration{
        asset: "a_9ac0f841265e8ad6d5c31792aff69225",
        sku_id: "1385050947792801852",
        expires_at: nil
      }
  """

  use EDA.Event.Access

  @discord_cdn "https://cdn.discordapp.com"

  defstruct [:asset, :sku_id, :expires_at]

  @type t :: %__MODULE__{
          asset: String.t() | nil,
          sku_id: String.t() | nil,
          expires_at: DateTime.t() | nil
        }

  @doc "Parses the raw `avatar_decoration_data` object. Returns `nil` when absent or null."
  @spec from_raw(map() | nil) :: t() | nil
  def from_raw(nil), do: nil

  def from_raw(raw) when is_map(raw) do
    %__MODULE__{
      asset: raw["asset"],
      sku_id: raw["sku_id"],
      expires_at: parse_expiry(raw["expires_at"])
    }
  end

  def from_raw(_), do: nil

  @doc """
  URL of the decoration, or `nil` when there is none.

  PNG only: an `a_` prefix marks an animated decoration, but the CDN answers 415 for any other
  extension, and the PNG it serves is the animation.

  ## Options

  - `:size` — power of two between 16 and 4096

  ## Examples

      iex> EDA.User.AvatarDecoration.url(%EDA.User.AvatarDecoration{asset: "a_abc"})
      "https://cdn.discordapp.com/avatar-decoration-presets/a_abc.png"

      iex> EDA.User.AvatarDecoration.url(nil)
      nil
  """
  @spec url(t() | nil, keyword()) :: String.t() | nil
  def url(decoration, opts \\ [])

  def url(%__MODULE__{asset: asset}, opts) when is_binary(asset) do
    query = if size = opts[:size], do: "?size=#{size}", else: ""
    "#{@discord_cdn}/avatar-decoration-presets/#{asset}.png#{query}"
  end

  def url(_decoration, _opts), do: nil

  # Undocumented, so tolerate both an ISO8601 string and a unix timestamp.
  defp parse_expiry(nil), do: nil

  defp parse_expiry(value) when is_binary(value) do
    case DateTime.from_iso8601(value) do
      {:ok, datetime, _offset} -> datetime
      {:error, _reason} -> nil
    end
  end

  defp parse_expiry(value) when is_integer(value) do
    case DateTime.from_unix(value) do
      {:ok, datetime} -> datetime
      {:error, _reason} -> nil
    end
  end

  defp parse_expiry(%DateTime{} = value), do: value
  defp parse_expiry(_value), do: nil
end
