defmodule EDA.GuildTemplate do
  @moduledoc """
  Represents a Discord Guild Template.

  Guild Templates allow users to create guilds from a predefined structure
  of channels, roles, and settings. Templates are identified by a unique
  alphanumeric code (e.g. `"hgM48av5Q69A"`).

  ## Fields

  | Field | Type | Description |
  |-------|------|-------------|
  | `code` | string | Unique template code |
  | `name` | string | Template name (1-100 chars) |
  | `description` | string \| nil | Description (0-120 chars) |
  | `usage_count` | integer | Times this template has been used |
  | `creator_id` | snowflake | ID of the template creator |
  | `creator` | `EDA.User` | The template's creator |
  | `created_at` | `DateTime` | When the template was created |
  | `updated_at` | `DateTime` | When it was last synced |
  | `source_guild_id` | snowflake | ID of the source guild |
  | `serialized_source_guild` | SourceGuild.t() | Guild snapshot |
  | `is_dirty` | boolean \| nil | Has unsynced changes |

  ## Constants

      EDA.GuildTemplate.max_name_length()        # => 100
      EDA.GuildTemplate.max_description_length()  # => 120
  """

  use EDA.Event.Access

  defstruct [
    :code,
    :name,
    :description,
    :usage_count,
    :creator_id,
    :creator,
    :created_at,
    :updated_at,
    :source_guild_id,
    :serialized_source_guild,
    :is_dirty
  ]

  @type t :: %__MODULE__{
          code: String.t() | nil,
          name: String.t() | nil,
          description: String.t() | nil,
          usage_count: integer() | nil,
          creator_id: String.t() | nil,
          creator: EDA.User.t() | nil,
          created_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil,
          source_guild_id: String.t() | nil,
          serialized_source_guild: EDA.GuildTemplate.SourceGuild.t() | nil,
          is_dirty: boolean() | nil
        }

  @doc "Maximum length for a template name (1-100 characters)."
  @spec max_name_length() :: 100
  def max_name_length, do: 100

  @doc "Maximum length for a template description (0-120 characters)."
  @spec max_description_length() :: 120
  def max_description_length, do: 120

  @doc """
  Converts a raw Discord guild template map into this struct.

  Parses `serialized_source_guild` into a `SourceGuild` struct.

  ## Examples

      iex> EDA.GuildTemplate.from_raw(%{"code" => "abc", "name" => "My Template", "usage_count" => 3})
      %EDA.GuildTemplate{code: "abc", name: "My Template", usage_count: 3}
  """
  @spec from_raw(map()) :: t()
  def from_raw(raw) when is_map(raw) do
    %__MODULE__{
      code: raw["code"],
      name: raw["name"],
      description: raw["description"],
      usage_count: raw["usage_count"],
      creator_id: raw["creator_id"],
      creator: parse_creator(raw["creator"]),
      created_at: EDA.Timestamp.parse(raw["created_at"]),
      updated_at: EDA.Timestamp.parse(raw["updated_at"]),
      source_guild_id: raw["source_guild_id"],
      serialized_source_guild: parse_source_guild(raw["serialized_source_guild"]),
      is_dirty: raw["is_dirty"]
    }
  end

  defp parse_source_guild(nil), do: nil

  defp parse_source_guild(raw) when is_map(raw) do
    EDA.GuildTemplate.SourceGuild.from_raw(raw)
  end

  defp parse_creator(nil), do: nil
  defp parse_creator(raw) when is_map(raw), do: EDA.User.from_raw(raw)
end

defmodule EDA.GuildTemplate.SourceGuild do
  @moduledoc """
  A serialized guild snapshot within a template.

  Note: All IDs in this struct are **placeholder integers**, not real snowflakes.
  For example, `@everyone` has id `0`, categories start at `1`, etc.

  `roles` and `channels` are `EDA.Role` and `EDA.Channel` structs holding the subset of fields a
  template keeps, with those placeholder integers as ids (`parent_id` and the overwrites' ids
  included). The levels are atoms, as on `EDA.Guild`.
  """

  use EDA.Event.Access

  defstruct [
    :name,
    :description,
    :region,
    :verification_level,
    :default_message_notifications,
    :explicit_content_filter,
    :preferred_locale,
    :afk_timeout,
    :afk_channel_id,
    :system_channel_id,
    :system_channel_flags,
    :icon_hash,
    :roles,
    :channels
  ]

  @type t :: %__MODULE__{
          name: String.t() | nil,
          description: String.t() | nil,
          region: String.t() | nil,
          verification_level: atom() | integer() | nil,
          default_message_notifications: atom() | integer() | nil,
          explicit_content_filter: atom() | integer() | nil,
          preferred_locale: String.t() | nil,
          afk_timeout: integer() | nil,
          afk_channel_id: integer() | nil,
          system_channel_id: integer() | nil,
          system_channel_flags: integer() | nil,
          icon_hash: String.t() | nil,
          roles: [EDA.Role.t()] | nil,
          channels: [EDA.Channel.t()] | nil
        }

  @doc """
  Converts a raw serialized source guild map into this struct.

  ## Examples

      iex> EDA.GuildTemplate.SourceGuild.from_raw(%{"name" => "My Guild", "roles" => [], "channels" => []})
      %EDA.GuildTemplate.SourceGuild{name: "My Guild", roles: [], channels: []}
  """
  @spec from_raw(map()) :: t()
  def from_raw(raw) when is_map(raw) do
    # The levels are read by EDA.Guild, whose tables they share.
    guild = EDA.Guild.from_raw(raw)

    %__MODULE__{
      name: raw["name"],
      description: raw["description"],
      region: raw["region"],
      verification_level: guild.verification_level,
      default_message_notifications: guild.default_message_notifications,
      explicit_content_filter: guild.explicit_content_filter,
      preferred_locale: raw["preferred_locale"],
      afk_timeout: raw["afk_timeout"],
      afk_channel_id: raw["afk_channel_id"],
      system_channel_id: raw["system_channel_id"],
      system_channel_flags: raw["system_channel_flags"],
      icon_hash: raw["icon_hash"],
      roles: raw["roles"] && Enum.map(raw["roles"], &EDA.Role.from_raw/1),
      channels: raw["channels"] && Enum.map(raw["channels"], &EDA.Channel.from_raw/1)
    }
  end
end
