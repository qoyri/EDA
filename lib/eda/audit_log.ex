defmodule EDA.AuditLog do
  @moduledoc "Audit log types, action type mappings, and pagination helpers."

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
  Returns a lazy Stream that paginates through audit log entries.
  Uses snowflake-based `before` pagination via `Stream.resource/3`.
  Stops when a page returns fewer entries than `per_page`.

  ## Options
  Same as `EDA.API.Guild.audit_log/2` plus:
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

        case EDA.API.Guild.audit_log(guild_id, query) do
          {:ok, %{entries: entries}} -> {:ok, entries}
          error -> error
        end
      end,
      cursor_key: fn entry -> entry.id end,
      direction: :before,
      per_page: per_page
    )
  end
end
