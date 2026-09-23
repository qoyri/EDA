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

  `data` is an `EDA.Interaction.CommandData` for a command or its autocomplete, an
  `EDA.Interaction.ComponentData` for a button or a select, and an
  `EDA.Interaction.ModalSubmitData` for a modal.
  """
  use EDA.Event.Access

  # EDA's names for the interaction types, public since before the rule of using Discord's names;
  # see EDA.Interaction.interaction_type/1.
  @types %{1 => :ping, 2 => :command, 3 => :component, 4 => :autocomplete, 5 => :modal_submit}

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
          type: :ping | :command | :component | :autocomplete | :modal_submit | integer() | nil,
          data:
            EDA.Interaction.CommandData.t()
            | EDA.Interaction.ComponentData.t()
            | EDA.Interaction.ModalSubmitData.t()
            | nil,
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
  def from_raw(%__MODULE__{} = parsed), do: parsed

  def from_raw(raw) when is_map(raw) do
    %__MODULE__{
      id: :maps.get("id", raw, nil),
      application_id: :maps.get("application_id", raw, nil),
      type: EDA.Enum.name(@types, :maps.get("type", raw, nil)),
      data: parse_data(:maps.get("type", raw, nil), :maps.get("data", raw, nil)),
      guild_id: :maps.get("guild_id", raw, nil),
      channel_id: :maps.get("channel_id", raw, nil),
      member: parse_member(:maps.get("member", raw, nil)),
      user: parse_user(:maps.get("user", raw, nil)),
      token: :maps.get("token", raw, nil),
      message: parse_message(:maps.get("message", raw, nil)),
      app_permissions: :maps.get("app_permissions", raw, nil),
      locale: :maps.get("locale", raw, nil),
      guild_locale: :maps.get("guild_locale", raw, nil),
      entitlements: parse_list(:maps.get("entitlements", raw, nil), &EDA.Entitlement.from_raw/1),
      guild: parse_one(:maps.get("guild", raw, nil), &EDA.Guild.from_raw/1),
      channel: parse_one(:maps.get("channel", raw, nil), &EDA.Channel.from_raw/1),
      context: parse_context(:maps.get("context", raw, nil)),
      authorizing_integration_owners:
        parse_owners(:maps.get("authorizing_integration_owners", raw, nil)),
      attachment_size_limit: :maps.get("attachment_size_limit", raw, nil),
      version: :maps.get("version", raw, nil)
    }
  end

  @contexts %{0 => :guild, 1 => :bot_dm, 2 => :private_channel}
  @integration_types %{"0" => :guild_install, "1" => :user_install}

  defp parse_context(nil), do: nil
  defp parse_context(value), do: Map.get(@contexts, value, value)

  @doc false
  # The data of an interaction, by its type (Discord's integer or EDA's atom). Shared with
  # EDA.Interaction, which also reads raw interaction maps.
  def parse_data(_type, nil), do: nil
  def parse_data(_type, %_{} = data), do: data

  def parse_data(type, raw) when type in [2, 4, :command, :autocomplete],
    do: EDA.Interaction.CommandData.from_raw(raw)

  def parse_data(type, raw) when type in [3, :component],
    do: EDA.Interaction.ComponentData.from_raw(raw)

  def parse_data(type, raw) when type in [5, :modal_submit],
    do: EDA.Interaction.ModalSubmitData.from_raw(raw)

  def parse_data(_type, raw), do: raw

  @doc false
  # The interaction type as EDA names it, shared with EDA.Message.InteractionMetadata.
  def type_name(type), do: EDA.Enum.name(@types, type)

  @doc false
  # Keyed by integration type; a type EDA does not know keeps its string key.
  def parse_owners(nil), do: nil

  def parse_owners(owners) when is_map(owners),
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
