defmodule EDA.AuditLog do
  @moduledoc """
  A guild's audit log: its `entries`, as `EDA.AuditLog.Entry` structs, and what they point at,
  so an entry's target can be named without another request — `users`, `webhooks`,
  `application_commands`, `auto_moderation_rules`, `guild_scheduled_events`, `integrations` and
  `threads` as their structs.

      {:ok, log} = EDA.AuditLog.fetch_log(guild_id, action_type: :member_ban_add, limit: 10)

  `stream/2` pages through the entries; `action_name/1` and `action_type/1` convert between the
  atoms and Discord's integers.
  """

  use EDA.Event.Access

  defstruct entries: [],
            users: [],
            webhooks: [],
            application_commands: [],
            auto_moderation_rules: [],
            guild_scheduled_events: [],
            integrations: [],
            threads: []

  @type t :: %__MODULE__{
          entries: [EDA.AuditLog.Entry.t()],
          users: [EDA.User.t()],
          webhooks: [EDA.Webhook.t()],
          application_commands: [EDA.Command.t()],
          auto_moderation_rules: [EDA.AutoMod.t()],
          guild_scheduled_events: [EDA.ScheduledEvent.t()],
          integrations: [EDA.Integration.t()],
          threads: [EDA.Channel.t()]
        }

  @action_types %{
    1 => :guild_update,
    10 => :channel_create,
    11 => :channel_update,
    12 => :channel_delete,
    13 => :channel_overwrite_create,
    14 => :channel_overwrite_update,
    15 => :channel_overwrite_delete,
    20 => :member_kick,
    21 => :member_prune,
    22 => :member_ban_add,
    23 => :member_ban_remove,
    24 => :member_update,
    25 => :member_role_update,
    26 => :member_move,
    27 => :member_disconnect,
    28 => :bot_add,
    30 => :role_create,
    31 => :role_update,
    32 => :role_delete,
    40 => :invite_create,
    41 => :invite_update,
    42 => :invite_delete,
    50 => :webhook_create,
    51 => :webhook_update,
    52 => :webhook_delete,
    60 => :emoji_create,
    61 => :emoji_update,
    62 => :emoji_delete,
    72 => :message_delete,
    73 => :message_bulk_delete,
    74 => :message_pin,
    75 => :message_unpin,
    80 => :integration_create,
    81 => :integration_update,
    82 => :integration_delete,
    83 => :stage_instance_create,
    84 => :stage_instance_update,
    85 => :stage_instance_delete,
    90 => :sticker_create,
    91 => :sticker_update,
    92 => :sticker_delete,
    100 => :guild_scheduled_event_create,
    101 => :guild_scheduled_event_update,
    102 => :guild_scheduled_event_delete,
    110 => :thread_create,
    111 => :thread_update,
    112 => :thread_delete,
    121 => :application_command_permission_update,
    130 => :soundboard_sound_create,
    131 => :soundboard_sound_update,
    132 => :soundboard_sound_delete,
    140 => :auto_moderation_rule_create,
    141 => :auto_moderation_rule_update,
    142 => :auto_moderation_rule_delete,
    143 => :auto_moderation_block_message,
    144 => :auto_moderation_flag_to_channel,
    145 => :auto_moderation_user_timeout,
    146 => :auto_moderation_quarantine_user,
    150 => :creator_monetization_request_created,
    151 => :creator_monetization_terms_accepted,
    163 => :onboarding_prompt_create,
    164 => :onboarding_prompt_update,
    165 => :onboarding_prompt_delete,
    166 => :onboarding_create,
    167 => :onboarding_update,
    190 => :home_settings_create,
    191 => :home_settings_update,
    192 => :voice_channel_status_create,
    193 => :voice_channel_status_delete
  }

  @reverse_types Map.new(@action_types, fn {k, v} -> {v, k} end)

  @doc "Converts an integer action type to an atom. Returns `:unknown` for unrecognized types."
  @spec action_name(integer()) :: atom()
  def action_name(name) when is_atom(name) and not is_nil(name), do: name

  def action_name(type) when is_integer(type) do
    Map.get(@action_types, type, :unknown)
  end

  @doc "Converts an atom action type to its integer value. Returns `nil` if not found."
  @spec action_type(atom()) :: integer() | nil
  def action_type(name) when is_atom(name) do
    Map.get(@reverse_types, name)
  end

  @doc "Returns all known action types as a map of integer => atom."
  @spec action_types() :: %{integer() => atom()}
  def action_types, do: @action_types

  @doc """
  An audit log as Discord sends it, with every list parsed.
  """
  @spec from_raw(map()) :: t()
  def from_raw(%__MODULE__{} = parsed), do: parsed

  def from_raw(raw) when is_map(raw) do
    %__MODULE__{
      entries: parse(:maps.get("audit_log_entries", raw, nil), &EDA.AuditLog.Entry.from_raw/1),
      users: parse(:maps.get("users", raw, nil), &EDA.User.from_raw/1),
      webhooks: parse(:maps.get("webhooks", raw, nil), &EDA.Webhook.from_raw/1),
      application_commands:
        parse(:maps.get("application_commands", raw, nil), &EDA.Command.from_raw/1),
      auto_moderation_rules:
        parse(:maps.get("auto_moderation_rules", raw, nil), &EDA.AutoMod.from_raw/1),
      guild_scheduled_events:
        parse(:maps.get("guild_scheduled_events", raw, nil), &EDA.ScheduledEvent.from_raw/1),
      integrations: parse(:maps.get("integrations", raw, nil), &EDA.Integration.from_raw/1),
      threads: parse(:maps.get("threads", raw, nil), &EDA.Channel.from_raw/1)
    }
  end

  defp parse(nil, _from_raw), do: []
  defp parse(list, from_raw), do: Enum.map(list, from_raw)

  @doc """
  Fetches a guild's audit log.

  Named `fetch_log/2` rather than `fetch/2` because `Access.fetch/2` owns that arity. Takes the
  options of `EDA.API.Guild.audit_log/2`: `:user_id`, `:action_type` (an atom or an integer),
  `:before`, `:after`, `:limit`.
  """
  @spec fetch_log(String.t() | integer(), keyword()) :: {:ok, t()} | {:error, term()}
  def fetch_log(guild_id, opts \\ []) do
    case EDA.API.Guild.audit_log(guild_id, opts) do
      {:ok, raw} when is_map(raw) -> {:ok, from_raw(raw)}
      {:error, _} = err -> err
    end
  end

  @doc """
  Returns a lazy Stream that paginates through audit log entries.
  Uses snowflake-based `before` pagination via `Stream.resource/3`.
  Stops when a page returns fewer entries than `per_page`.

  ## Options
  Same as `fetch_log/2` plus:
  - `:per_page` — entries per page (default 50, max 100)

  ## Example
      EDA.AuditLog.stream("guild_id", action_type: EDA.AuditLog.action_type(:member_ban_add))
      |> Stream.take(200)
      |> Enum.to_list()
  """
  @spec stream(String.t() | integer(), keyword()) :: Enumerable.t()
  def stream(guild_id, opts \\ []) do
    {per_page, opts} = Keyword.pop(opts, :per_page, 50)
    per_page = min(per_page, 100)

    EDA.Paginator.stream(
      fetch: fn cursor ->
        query = [{:limit, per_page} | opts]
        query = if cursor, do: [{:before, cursor} | query], else: query

        case fetch_log(guild_id, query) do
          {:ok, %__MODULE__{entries: entries}} -> {:ok, entries}
          error -> error
        end
      end,
      cursor_key: fn entry -> entry.id end,
      direction: :before,
      per_page: per_page
    )
  end
end
