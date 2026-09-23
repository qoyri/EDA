defmodule EDA.Event.InteractionCreate do
  @moduledoc """
  Sent when a user runs a command, uses a component, submits a modal or triggers autocomplete.

  Besides the ids, `guild` and `channel` carry the partial guild (its locale and features) and
  channel Discord attaches — the only channel data a user-installed command gets in a guild the
  bot is not in. `context` says where the interaction came from (`:guild`, `:bot_dm`,
  `:private_channel`, or the integer Discord sent if it is new), and
  `authorizing_integration_owners` which installations authorised it:
  `%{guild_install: guild_id, user_install: user_id}`. A key is missing when that installation
  was not involved, and the guild installation's value is `"0"` in a DM with the bot.
  `attachment_size_limit` is the largest upload the response may carry, in bytes.
  """
  use EDA.Event.Access

  defstruct [
    :id,
    :application_id,
    :type,
    :data,
    :guild_id,
    :channel_id,
    :member,
    :user,
    :token,
    :message,
    :app_permissions,
    :locale,
    :guild_locale,
    :entitlements,
    :guild,
    :channel,
    :context,
    :authorizing_integration_owners,
    :attachment_size_limit,
    :version
  ]

  @type t :: %__MODULE__{
          id: String.t() | nil,
          application_id: String.t() | nil,
          type: integer() | nil,
          data: map() | nil,
          guild_id: String.t() | nil,
          channel_id: String.t() | nil,
          member: EDA.Member.t() | nil,
          user: EDA.User.t() | nil,
          token: String.t() | nil,
          message: EDA.Message.t() | nil,
          app_permissions: String.t() | nil,
          locale: String.t() | nil,
          guild_locale: String.t() | nil,
          entitlements: [EDA.Entitlement.t()] | nil,
          guild: EDA.Guild.t() | nil,
          channel: EDA.Channel.t() | nil,
          context: :guild | :bot_dm | :private_channel | integer() | nil,
          authorizing_integration_owners: %{optional(atom() | String.t()) => String.t()} | nil,
          attachment_size_limit: non_neg_integer() | nil,
          version: integer() | nil
        }
  @doc "Converts a raw Discord payload into this event struct."
  @spec from_raw(map()) :: t()
  def from_raw(raw) when is_map(raw) do
    %__MODULE__{
      id: raw["id"],
      application_id: raw["application_id"],
      type: raw["type"],
      data: raw["data"],
      guild_id: raw["guild_id"],
      channel_id: raw["channel_id"],
      member: parse_member(raw["member"]),
      user: parse_user(raw["user"]),
      token: raw["token"],
      message: parse_message(raw["message"]),
      app_permissions: raw["app_permissions"],
      locale: raw["locale"],
      guild_locale: raw["guild_locale"],
      entitlements: parse_list(raw["entitlements"], &EDA.Entitlement.from_raw/1),
      guild: parse_one(raw["guild"], &EDA.Guild.from_raw/1),
      channel: parse_one(raw["channel"], &EDA.Channel.from_raw/1),
      context: parse_context(raw["context"]),
      authorizing_integration_owners: parse_owners(raw["authorizing_integration_owners"]),
      attachment_size_limit: raw["attachment_size_limit"],
      version: raw["version"]
    }
  end

  @contexts %{0 => :guild, 1 => :bot_dm, 2 => :private_channel}
  @integration_types %{"0" => :guild_install, "1" => :user_install}

  defp parse_context(nil), do: nil
  defp parse_context(value), do: Map.get(@contexts, value, value)

  # Keyed by integration type; a type EDA does not know keeps its string key.
  defp parse_owners(nil), do: nil

  defp parse_owners(owners) when is_map(owners),
    do: Map.new(owners, fn {type, id} -> {Map.get(@integration_types, type, type), id} end)

  defp parse_one(nil, _parse), do: nil
  defp parse_one(raw, parse) when is_map(raw), do: parse.(raw)

  defp parse_list(nil, _parse), do: nil
  defp parse_list(list, parse) when is_list(list), do: Enum.map(list, parse)

  defp parse_user(nil), do: nil
  defp parse_user(raw) when is_map(raw), do: EDA.User.from_raw(raw)

  defp parse_member(nil), do: nil
  defp parse_member(raw) when is_map(raw), do: EDA.Member.from_raw(raw)

  defp parse_message(nil), do: nil
  defp parse_message(raw) when is_map(raw), do: EDA.Message.from_raw(raw)
end
