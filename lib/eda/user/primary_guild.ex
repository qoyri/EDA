defmodule EDA.User.PrimaryGuild do
  @moduledoc """
  A user's primary guild — the "server tag" shown next to their name.

  Optional and nullable on the user object: the key is present for every user, but
  is `nil` unless they display a tag. Observed on a real guild (2026-09-19): 160 of
  574 cached users had a non-nil value.

  `identity_enabled` is deliberately tri-state — `true` when the tag is shown,
  `false` when the user removed it manually, and `nil` when Discord cleared the
  identity itself.

  ## Example

      %EDA.User.PrimaryGuild{
        identity_guild_id: "1508992262657409046",
        identity_enabled: true,
        tag: "BABL",
        badge: "22957f5661c149eefe1ba25d2bec7060"
      }
  """

  use EDA.Event.Access

  @discord_cdn "https://cdn.discordapp.com"

  defstruct [:identity_guild_id, :identity_enabled, :tag, :badge]

  @type t :: %__MODULE__{
          identity_guild_id: String.t() | nil,
          identity_enabled: boolean() | nil,
          tag: String.t() | nil,
          badge: String.t() | nil
        }

  @doc "Parses the raw `primary_guild` object. Returns `nil` when absent or null."
  @spec from_raw(map() | nil) :: t() | nil
  def from_raw(nil), do: nil

  def from_raw(raw) when is_map(raw) do
    %__MODULE__{
      identity_guild_id: raw["identity_guild_id"],
      identity_enabled: raw["identity_enabled"],
      tag: raw["tag"],
      badge: raw["badge"]
    }
  end

  def from_raw(_), do: nil

  @doc """
  Returns `true` only when the user is actually displaying a server tag.

  Guards against the tri-state `identity_enabled` and against a tag being present
  while disabled.

  ## Examples

      iex> EDA.User.PrimaryGuild.displayed?(%EDA.User.PrimaryGuild{identity_enabled: true, tag: "DISC"})
      true

      iex> EDA.User.PrimaryGuild.displayed?(%EDA.User.PrimaryGuild{identity_enabled: false, tag: "DISC"})
      false

      iex> EDA.User.PrimaryGuild.displayed?(nil)
      false
  """
  @spec displayed?(t() | nil) :: boolean()
  def displayed?(%__MODULE__{identity_enabled: true, tag: tag}) when is_binary(tag), do: true
  def displayed?(%__MODULE__{}), do: false
  def displayed?(nil), do: false

  @doc """
  URL of the server tag badge, or `nil` when there is none.

  ## Options

  - `:size` — power of two between 16 and 4096

  ## Examples

      iex> EDA.User.PrimaryGuild.badge_url(%EDA.User.PrimaryGuild{identity_guild_id: "1", badge: "abc"})
      "https://cdn.discordapp.com/guild-tag-badges/1/abc.png"
  """
  @spec badge_url(t() | nil, keyword()) :: String.t() | nil
  def badge_url(primary_guild, opts \\ [])

  def badge_url(%__MODULE__{identity_guild_id: guild_id, badge: badge}, opts)
      when is_binary(guild_id) and is_binary(badge) do
    query = if size = opts[:size], do: "?size=#{size}", else: ""
    "#{@discord_cdn}/guild-tag-badges/#{guild_id}/#{badge}.png#{query}"
  end

  def badge_url(_primary_guild, _opts), do: nil
end
