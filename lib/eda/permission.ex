defmodule EDA.Permission do
  @moduledoc """
  Discord permission flags and calculator.

  Computes effective permissions for a member at guild or channel level,
  following Discord's official algorithm with the 3-tier overwrite cascade.

  ## Features

  - **Correct 3-tier overwrite cascade**: @everyone → roles (merged) → member
  - **Access gates**: returns `0` if VIEW_CHANNEL is missing, or if
    VOICE_CONNECT is missing on voice/stage channels
  - **`has_permission?/3`**: one-call convenience for permission checks
  - **Pure bitwise hot path**: no atom-list conversion during calculation
  - **All 50+ Discord permissions** up to date (bit 52)
  - **Nil-safe**: returns `{:error, reason}` instead of crashing on missing data

  ## Usage

      # Check if a member can manage messages in a channel
      EDA.Permission.has_permission?(guild_id, user_id, channel_id, :manage_messages)

      # Get all effective permissions in a channel
      {:ok, bitset} = EDA.Permission.in_channel(guild_id, user_id, channel_id)
      perms = EDA.Permission.to_list(bitset)

      # Guild-level permissions
      {:ok, bitset} = EDA.Permission.in_guild(guild_id, user_id)
  """

  import Bitwise

  # ── Permission Flags ──────────────────────────────────────────────

  @flags %{
    create_instant_invite: 1 <<< 0,
    kick_members: 1 <<< 1,
    ban_members: 1 <<< 2,
    administrator: 1 <<< 3,
    manage_channels: 1 <<< 4,
    manage_guild: 1 <<< 5,
    add_reactions: 1 <<< 6,
    view_audit_log: 1 <<< 7,
    priority_speaker: 1 <<< 8,
    stream: 1 <<< 9,
    view_channel: 1 <<< 10,
    send_messages: 1 <<< 11,
    send_tts_messages: 1 <<< 12,
    manage_messages: 1 <<< 13,
    embed_links: 1 <<< 14,
    attach_files: 1 <<< 15,
    read_message_history: 1 <<< 16,
    mention_everyone: 1 <<< 17,
    use_external_emojis: 1 <<< 18,
    view_guild_insights: 1 <<< 19,
    connect: 1 <<< 20,
    speak: 1 <<< 21,
    mute_members: 1 <<< 22,
    deafen_members: 1 <<< 23,
    move_members: 1 <<< 24,
    use_vad: 1 <<< 25,
    change_nickname: 1 <<< 26,
    manage_nicknames: 1 <<< 27,
    manage_roles: 1 <<< 28,
    manage_webhooks: 1 <<< 29,
    manage_guild_expressions: 1 <<< 30,
    use_application_commands: 1 <<< 31,
    request_to_speak: 1 <<< 32,
    manage_events: 1 <<< 33,
    manage_threads: 1 <<< 34,
    create_public_threads: 1 <<< 35,
    create_private_threads: 1 <<< 36,
    use_external_stickers: 1 <<< 37,
    send_messages_in_threads: 1 <<< 38,
    use_embedded_activities: 1 <<< 39,
    moderate_members: 1 <<< 40,
    view_creator_monetization_analytics: 1 <<< 41,
    use_soundboard: 1 <<< 42,
    create_guild_expressions: 1 <<< 43,
    create_events: 1 <<< 44,
    use_external_sounds: 1 <<< 45,
    send_voice_messages: 1 <<< 46,
    set_voice_channel_status: 1 <<< 48,
    send_polls: 1 <<< 49,
    use_external_apps: 1 <<< 50,
    pin_messages: 1 <<< 51,
    bypass_slowmode: 1 <<< 52
  }

  @all_permissions Map.values(@flags) |> Enum.reduce(0, &bor/2)

  @bit_to_flag Map.new(@flags, fn {k, v} -> {v, k} end)

  @max_bit 52

  # Voice and stage channel types
  # A cached channel carries its type as an atom; a raw one, as Discord's integer.
  @voice_types [2, 13, :guild_voice, :guild_stage_voice]

  @type flag ::
          :create_instant_invite
          | :kick_members
          | :ban_members
          | :administrator
          | :manage_channels
          | :manage_guild
          | :add_reactions
          | :view_audit_log
          | :priority_speaker
          | :stream
          | :view_channel
          | :send_messages
          | :send_tts_messages
          | :manage_messages
          | :embed_links
          | :attach_files
          | :read_message_history
          | :mention_everyone
          | :use_external_emojis
          | :view_guild_insights
          | :connect
          | :speak
          | :mute_members
          | :deafen_members
          | :move_members
          | :use_vad
          | :change_nickname
          | :manage_nicknames
          | :manage_roles
          | :manage_webhooks
          | :manage_guild_expressions
          | :use_application_commands
          | :request_to_speak
          | :manage_events
          | :manage_threads
          | :create_public_threads
          | :create_private_threads
          | :use_external_stickers
          | :send_messages_in_threads
          | :use_embedded_activities
          | :moderate_members
          | :view_creator_monetization_analytics
          | :use_soundboard
          | :create_guild_expressions
          | :create_events
          | :use_external_sounds
          | :send_voice_messages
          | :set_voice_channel_status
          | :send_polls
          | :use_external_apps
          | :pin_messages
          | :bypass_slowmode

  @type bitset :: non_neg_integer()

  # ── Conversion Functions ──────────────────────────────────────────

  @doc "Returns the bit value for a permission flag."
  @spec to_bit(flag()) :: bitset()
  def to_bit(flag) when is_map_key(@flags, flag), do: Map.fetch!(@flags, flag)

  @doc "Returns the flag atom for a bit value, or `:error`."
  @spec from_bit(bitset()) :: {:ok, flag()} | :error
  def from_bit(bit) do
    case Map.fetch(@bit_to_flag, bit) do
      {:ok, _} = ok -> ok
      :error -> :error
    end
  end

  @doc "Converts a list of flag atoms to a combined bitset."
  @spec to_bitset([flag()]) :: bitset()
  def to_bitset(flags) when is_list(flags) do
    Enum.reduce(flags, 0, fn flag, acc -> acc ||| Map.fetch!(@flags, flag) end)
  end

  @doc "Converts a bitset to a list of flag atoms. Unknown bits are skipped."
  @spec to_list(bitset()) :: [flag()]
  def to_list(bitset) when is_integer(bitset) do
    for i <- 0..@max_bit,
        mask = 1 <<< i,
        (bitset &&& mask) == mask,
        flag = Map.get(@bit_to_flag, mask),
        flag != nil,
        do: flag
  end

  @doc "Returns the bitset with all permissions set."
  @spec all() :: bitset()
  def all, do: @all_permissions

  # ── Classification ────────────────────────────────────────────────
  #
  # Generated from Discord's own Bitwise Permission Flags table
  # (discord-api-docs, developers/topics/permissions.mdx) rather than transcribed by
  # hand: the "Channel Type" column marks each permission T (text), V (voice) and/or
  # S (stage). An empty list means the permission only has meaning at guild level and
  # is inert in a channel overwrite.
  @channel_types %{
    create_instant_invite: [:text, :voice, :stage],
    kick_members: [],
    ban_members: [],
    administrator: [],
    manage_channels: [:text, :voice, :stage],
    manage_guild: [],
    add_reactions: [:text, :voice, :stage],
    view_audit_log: [],
    priority_speaker: [:voice],
    stream: [:voice, :stage],
    view_channel: [:text, :voice, :stage],
    send_messages: [:text, :voice, :stage],
    send_tts_messages: [:text, :voice, :stage],
    manage_messages: [:text, :voice, :stage],
    embed_links: [:text, :voice, :stage],
    attach_files: [:text, :voice, :stage],
    read_message_history: [:text, :voice, :stage],
    mention_everyone: [:text, :voice, :stage],
    use_external_emojis: [:text, :voice, :stage],
    view_guild_insights: [],
    connect: [:voice, :stage],
    speak: [:voice],
    mute_members: [:voice, :stage],
    deafen_members: [:voice],
    move_members: [:voice, :stage],
    use_vad: [:voice],
    change_nickname: [],
    manage_nicknames: [],
    manage_roles: [:text, :voice, :stage],
    manage_webhooks: [:text, :voice, :stage],
    manage_guild_expressions: [],
    use_application_commands: [:text, :voice, :stage],
    request_to_speak: [:stage],
    manage_events: [:voice, :stage],
    manage_threads: [:text],
    create_public_threads: [:text],
    create_private_threads: [:text],
    use_external_stickers: [:text, :voice, :stage],
    send_messages_in_threads: [:text],
    use_embedded_activities: [:text, :voice],
    moderate_members: [],
    view_creator_monetization_analytics: [],
    use_soundboard: [:voice],
    create_guild_expressions: [],
    create_events: [:voice, :stage],
    use_external_sounds: [:voice],
    send_voice_messages: [:text, :voice, :stage],
    set_voice_channel_status: [:voice],
    send_polls: [:text, :voice, :stage],
    use_external_apps: [:text, :voice, :stage],
    pin_messages: [:text],
    bypass_slowmode: [:text, :voice, :stage]
  }

  @typedoc "A channel category a permission can apply to."
  @type channel_kind :: :text | :voice | :stage

  @doc """
  The channel kinds a permission applies to.

  An empty list means the permission is guild-level only — setting it in a channel
  overwrite has no effect.

  ## Examples

      iex> EDA.Permission.channel_types(:send_messages)
      [:text, :voice, :stage]

      iex> EDA.Permission.channel_types(:kick_members)
      []

      iex> EDA.Permission.channel_types(:request_to_speak)
      [:stage]
  """
  @spec channel_types(flag()) :: [channel_kind()]
  def channel_types(flag) when is_map_key(@channel_types, flag),
    do: Map.fetch!(@channel_types, flag)

  @doc """
  Returns `true` for a permission that only has meaning at guild level.

  ## Examples

      iex> EDA.Permission.guild_only?(:kick_members)
      true

      iex> EDA.Permission.guild_only?(:send_messages)
      false
  """
  @spec guild_only?(flag()) :: boolean()
  def guild_only?(flag), do: channel_types(flag) == []

  @doc """
  Returns `true` for a permission that can meaningfully appear in a channel overwrite.

  ## Examples

      iex> EDA.Permission.channel?(:send_messages)
      true

      iex> EDA.Permission.channel?(:administrator)
      false
  """
  @spec channel?(flag()) :: boolean()
  def channel?(flag), do: channel_types(flag) != []

  @doc """
  Returns `true` if the permission applies to the given channel.

  The second argument is a channel kind (`:text`, `:voice`, `:stage`), a channel type as an
  atom (`:guild_voice`) or Discord's integer, or a channel struct or map. Categories accept
  every kind, since their overwrites cascade to children of any type.

  ## Examples

      iex> EDA.Permission.applies_to?(:request_to_speak, :stage)
      true

      iex> EDA.Permission.applies_to?(:request_to_speak, :text)
      false

      iex> EDA.Permission.applies_to?(:kick_members, :text)
      false
  """
  @spec applies_to?(flag(), channel_kind() | integer() | map()) :: boolean()
  def applies_to?(flag, kind) when kind in [:text, :voice, :stage],
    do: kind in channel_types(flag)

  def applies_to?(flag, %{"type" => type}), do: applies_to?(flag, type)
  def applies_to?(flag, %{type: type}) when not is_nil(type), do: applies_to?(flag, type)

  # A channel type atom (`:guild_voice`), as `EDA.Channel.type` holds it.
  def applies_to?(flag, type) when is_atom(type) and not is_nil(type),
    do: applies_to?(flag, EDA.Channel.type_value(type))

  def applies_to?(flag, type) when is_integer(type) do
    case channel_kind(type) do
      :any -> channel?(flag)
      nil -> false
      kind -> kind in channel_types(flag)
    end
  end

  def applies_to?(_flag, _channel), do: false

  @doc """
  Lists the permissions in a bitset that have **no effect** in the given channel.

  Use it to catch a meaningless overwrite before sending it — Discord accepts
  `KICK_MEMBERS` in a channel overwrite and silently ignores it. Neither JDA nor
  Nostrum offers this check.

  ## Examples

      iex> bitset = EDA.Permission.to_bitset([:send_messages, :kick_members])
      iex> EDA.Permission.inapplicable(bitset, :text)
      [:kick_members]

      iex> EDA.Permission.inapplicable(EDA.Permission.to_bitset([:send_messages]), :text)
      []
  """
  @spec inapplicable(bitset(), channel_kind() | integer() | map()) :: [flag()]
  def inapplicable(bitset, channel) when is_integer(bitset) do
    bitset
    |> to_list()
    |> Enum.reject(&applies_to?(&1, channel))
    |> Enum.sort()
  end

  # Category overwrites cascade to children of any type, so nothing is inert there.
  defp channel_kind(4), do: :any
  defp channel_kind(2), do: :voice
  defp channel_kind(13), do: :stage
  defp channel_kind(type) when type in [0, 5, 10, 11, 12, 15, 16], do: :text
  defp channel_kind(_type), do: nil

  @doc "Returns all known permission flag atoms."
  @spec all_flags() :: [flag()]
  def all_flags, do: Map.keys(@flags)

  @doc "Checks if a specific flag is set in a bitset."
  @spec has?(bitset(), flag()) :: boolean()
  def has?(bitset, flag) when is_integer(bitset) and is_map_key(@flags, flag) do
    bit = Map.fetch!(@flags, flag)
    (bitset &&& bit) == bit
  end

  @doc """
  The flags of `required` that the bitset lacks, in the order given — what to name in a "missing
  permissions" reply.

      iex> perms = EDA.Permission.to_bitset([:send_messages])
      iex> EDA.Permission.missing(perms, [:send_messages, :embed_links, :attach_files])
      [:embed_links, :attach_files]
  """
  @spec missing(bitset(), [flag()]) :: [flag()]
  def missing(bitset, required) when is_integer(bitset) and is_list(required),
    do: Enum.reject(required, &has?(bitset, &1))

  @doc """
  Whether the bitset holds any of the flags.

      iex> EDA.Permission.any?(EDA.Permission.to_bitset([:kick_members]), [:ban_members, :kick_members])
      true
  """
  @spec any?(bitset(), [flag()]) :: boolean()
  def any?(bitset, flags) when is_integer(bitset) and is_list(flags),
    do: Enum.any?(flags, &has?(bitset, &1))

  # ── Permission Calculator ─────────────────────────────────────────

  @doc """
  Computes effective guild-level permissions for a member.

  Returns `{:ok, bitset}` or `{:error, reason}`.

  ## Algorithm
  1. Guild owner → ALL_PERMISSIONS
  2. OR all role permission bits together
  3. If ADMINISTRATOR is set → ALL_PERMISSIONS
  """
  @spec in_guild(String.t(), String.t()) :: {:ok, bitset()} | {:error, term()}
  def in_guild(guild_id, user_id) do
    guild_id = to_string(guild_id)
    user_id = to_string(user_id)

    with {:guild, guild} when guild != nil <- {:guild, EDA.Cache.get_guild(guild_id)},
         {:member, member} when member != nil <-
           {:member, EDA.Cache.get_member(guild_id, user_id)} do
      {:ok, compute_guild_permissions(guild, member)}
    else
      {:guild, nil} -> {:error, :guild_not_found}
      {:member, nil} -> {:error, :member_not_found}
    end
  end

  @doc """
  Computes effective guild-level permissions for a member already in hand: an `EDA.Member`, or a
  raw member map such as the one an interaction carries.

  Unlike `in_guild/2`, the member need not be cached — without the `GUILD_MEMBERS` intent, most
  are not. Only the guild and its roles are read from the cache.

  For the channel an interaction was used in, Discord already sends the member's permissions
  there, overwrites included, as `member.permissions`.

  Returns `{:ok, bitset}` or `{:error, reason}`.

      {:ok, perms} = EDA.Permission.for_member(interaction.member, interaction.guild_id)
      EDA.Permission.has?(perms, :ban_members)
  """
  @spec for_member(EDA.Member.t() | map(), String.t() | integer()) ::
          {:ok, bitset()} | {:error, term()}
  def for_member(member, guild_id) do
    with {:member, member} when member != nil <- {:member, member_raw(member)},
         {:guild, guild} when guild != nil <- {:guild, EDA.Cache.get_guild(to_string(guild_id))} do
      {:ok, compute_guild_permissions(guild, member)}
    else
      {:member, nil} -> {:error, :member_without_user}
      {:guild, nil} -> {:error, :guild_not_found}
    end
  end

  defp member_raw(%EDA.Member{user: %{id: id}} = member) when id != nil, do: member

  defp member_raw(%EDA.Member{}), do: nil
  defp member_raw(%{"user" => %{"id" => _}} = raw), do: raw
  defp member_raw(%{"user_id" => _} = raw), do: raw
  defp member_raw(_), do: nil

  @doc """
  Computes effective channel-level permissions for a member.

  Returns `{:ok, bitset}` or `{:error, reason}`.

  ## Algorithm (matches Discord's official spec + JDA)
  1. Owner → ALL_PERMISSIONS
  2. Compute guild base permissions
  3. ADMINISTRATOR → ALL_PERMISSIONS (skips all overwrites)
  4. Apply 3-tier overwrite cascade:
     a. @everyone role overwrite
     b. All role overwrites (merged via OR, then applied)
     c. Member-specific overwrite (highest priority)
  5. Access gate: no VIEW_CHANNEL → 0
  6. Access gate: voice/stage channel + no CONNECT → 0

  ## Obfuscated channels

  Returns `{:error, :channel_obfuscated}` for a channel Discord has redacted because
  the bot cannot view it (see `EDA.Channel.obfuscated?/1`). Such a channel carries a
  single synthetic overwrite denying `VIEW_CHANNEL` to `@everyone`, which is
  indistinguishable from a real one — computing from it would return a confident but
  meaningless answer, so the ambiguity is surfaced to the caller instead.

  `has_permission?/4` maps this to `false`, like any other error.
  """
  @spec in_channel(String.t(), String.t(), String.t()) :: {:ok, bitset()} | {:error, term()}
  def in_channel(guild_id, user_id, channel_id) do
    guild_id = to_string(guild_id)
    user_id = to_string(user_id)
    channel_id = to_string(channel_id)

    with {:guild, guild} when guild != nil <- {:guild, EDA.Cache.get_guild(guild_id)},
         {:member, member} when member != nil <-
           {:member, EDA.Cache.get_member(guild_id, user_id)},
         {:channel, channel} when channel != nil <- {:channel, EDA.Cache.get_channel(channel_id)},
         {:obfuscated, false} <- {:obfuscated, EDA.Channel.obfuscated?(channel)} do
      {:ok, compute_channel_permissions(guild, member, channel)}
    else
      {:guild, nil} -> {:error, :guild_not_found}
      {:member, nil} -> {:error, :member_not_found}
      {:channel, nil} -> {:error, :channel_not_found}
      {:obfuscated, true} -> {:error, :channel_obfuscated}
    end
  end

  @typedoc """
  A step in a permission derivation.

  `:stage` is `:owner`, `:administrator`, `:role_base`, `:everyone_overwrite`,
  `:role_overwrites`, `:member_overwrite` or `:gate`. Overwrite stages carry the
  `:allow` and `:deny` bitsets that were applied; gate stages carry `:gate`.
  `:result` is the running permission bitset after that step.
  """
  @type step :: %{
          required(:stage) => atom(),
          required(:result) => bitset(),
          optional(:allow) => bitset(),
          optional(:deny) => bitset(),
          optional(:gate) => atom()
        }

  @typedoc "A full permission derivation, as returned by `explain/3`."
  @type explanation :: %{
          effective: bitset(),
          base: bitset(),
          steps: [step()],
          gates: [atom()],
          denied_by: atom() | nil
        }

  @doc """
  Explains **how** a member's channel permissions were derived.

  `in_channel/3` answers *what* a member may do; this answers *why*. Neither JDA nor
  Nostrum exposes the derivation, and "why can't my bot post here" is usually answered
  by guesswork against an opaque integer.

  Returns the same `:effective` bitset as `in_channel/3`, plus:

    * `:base` — guild-level permissions from the member's roles, before overwrites;
    * `:steps` — the derivation in order, each with the running `:result`. Overwrite
      steps carry the `:allow`/`:deny` bitsets that were applied;
    * `:gates` — which access gates fired (`:timed_out`, `:no_view_channel`, `:no_connect`);
    * `:denied_by` — the gate that reduced the result to zero, or `nil`.

  Owner and administrator short-circuit to every permission, and say so in a single step.

  ## Examples

      {:ok, why} = EDA.Permission.explain(guild_id, user_id, channel_id)

      why.denied_by
      #=> :no_view_channel

      Enum.map(why.steps, & &1.stage)
      #=> [:role_base, :everyone_overwrite, :role_overwrites, :member_overwrite, :gate]

      # what the @everyone overwrite took away
      why.steps
      |> Enum.find(&(&1.stage == :everyone_overwrite))
      |> Map.fetch!(:deny)
      |> EDA.Permission.to_list()
      #=> [:send_messages]
  """
  @spec explain(String.t(), String.t(), String.t()) ::
          {:ok, explanation()} | {:error, term()}
  def explain(guild_id, user_id, channel_id) do
    guild_id = to_string(guild_id)
    user_id = to_string(user_id)
    channel_id = to_string(channel_id)

    with {:guild, guild} when guild != nil <- {:guild, EDA.Cache.get_guild(guild_id)},
         {:member, member} when member != nil <-
           {:member, EDA.Cache.get_member(guild_id, user_id)},
         {:channel, channel} when channel != nil <- {:channel, EDA.Cache.get_channel(channel_id)},
         {:obfuscated, false} <- {:obfuscated, EDA.Channel.obfuscated?(channel)} do
      {:ok, trace_channel_permissions(guild, member, channel)}
    else
      {:guild, nil} -> {:error, :guild_not_found}
      {:member, nil} -> {:error, :member_not_found}
      {:channel, nil} -> {:error, :channel_not_found}
      {:obfuscated, true} -> {:error, :channel_obfuscated}
    end
  end

  @doc """
  Checks if a member has a specific permission in a channel.

  Convenience function — most common use case for bots.
  """
  @spec has_permission?(String.t(), String.t(), String.t(), flag()) :: boolean()
  def has_permission?(guild_id, user_id, channel_id, permission) do
    case in_channel(guild_id, user_id, channel_id) do
      {:ok, bitset} -> has?(bitset, permission)
      {:error, _} -> false
    end
  end

  @doc """
  Checks if a member has a specific permission at guild level.
  """
  @spec has_guild_permission?(String.t(), String.t(), flag()) :: boolean()
  def has_guild_permission?(guild_id, user_id, permission) do
    case in_guild(guild_id, user_id) do
      {:ok, bitset} -> has?(bitset, permission)
      {:error, _} -> false
    end
  end

  # ── Internal: Guild-Level ─────────────────────────────────────────

  @doc false
  def compute_guild_permissions(guild, member) do
    user_id = get_user_id(member)

    if guild["owner_id"] == user_id do
      @all_permissions
    else
      base = aggregate_role_permissions(guild, member)

      if (base &&& @flags.administrator) == @flags.administrator,
        do: @all_permissions,
        else: base
    end
  end

  defp aggregate_role_permissions(guild, member) do
    everyone_role_id = guild["id"]
    member_role_ids = [everyone_role_id | member["roles"] || []]

    Enum.reduce(member_role_ids, 0, fn role_id, acc ->
      case EDA.Cache.get_role(role_id) do
        nil -> acc
        role -> acc ||| parse_permissions(role["permissions"])
      end
    end)
  end

  # ── Internal: Channel-Level ───────────────────────────────────────

  @doc false
  def compute_channel_permissions(guild, member, channel) do
    trace_channel_permissions(guild, member, channel).effective
  end

  @doc false
  @spec trace_channel_permissions(map(), map(), map()) :: explanation()
  def trace_channel_permissions(guild, member, channel) do
    user_id = get_user_id(member)
    base = compute_guild_permissions(guild, member)

    cond do
      guild["owner_id"] == user_id ->
        %{
          effective: @all_permissions,
          base: base,
          steps: [%{stage: :owner, result: @all_permissions}],
          gates: [],
          denied_by: nil
        }

      admin?(base) ->
        %{
          effective: @all_permissions,
          base: base,
          steps: [%{stage: :administrator, result: @all_permissions}],
          gates: [],
          denied_by: nil
        }

      true ->
        {after_overwrites, overwrite_steps} = trace_overwrites(base, guild, member, channel)
        {effective, gate_steps, gates, denied_by} = trace_gates(after_overwrites, member, channel)

        %{
          effective: effective,
          base: base,
          steps: [%{stage: :role_base, result: base} | overwrite_steps] ++ gate_steps,
          gates: gates,
          denied_by: denied_by
        }
    end
  end

  defp admin?(bitset), do: (bitset &&& @flags.administrator) == @flags.administrator

  @timeout_retained @flags.view_channel ||| @flags.read_message_history

  defp trace_gates(perms, member, channel) do
    {perms, steps, gates} =
      if EDA.Member.timed_out?(member) do
        restricted = perms &&& @timeout_retained

        {restricted, [%{stage: :gate, gate: :timed_out, result: restricted}], [:timed_out]}
      else
        {perms, [], []}
      end

    cond do
      (perms &&& @flags.view_channel) != @flags.view_channel ->
        {0, steps ++ [%{stage: :gate, gate: :no_view_channel, result: 0}],
         gates ++ [:no_view_channel], :no_view_channel}

      (channel["type"] || 0) in @voice_types and (perms &&& @flags.connect) != @flags.connect ->
        {0, steps ++ [%{stage: :gate, gate: :no_connect, result: 0}], gates ++ [:no_connect],
         :no_connect}

      true ->
        {perms, steps, gates, nil}
    end
  end

  # ── Internal: 3-Tier Overwrite Cascade ────────────────────────────
  # Matches Discord's official algorithm and JDA's PermissionUtil.
  #
  # Tier 1: @everyone role overwrite
  # Tier 2: All role overwrites (merged via OR)
  # Tier 3: Member-specific overwrite
  #
  # We apply each tier sequentially so member overwrites always win.

  defp trace_overwrites(base, guild, member, channel) do
    overwrites = channel["permission_overwrites"] || []
    everyone_role_id = to_string(guild["id"])
    user_id = get_user_id(member)
    member_role_ids = MapSet.new(Enum.map(member["roles"] || [], &to_string/1))

    # Index overwrites by ID for O(1) lookup
    overwrite_map = Map.new(overwrites, fn ow -> {to_string(ow["id"]), ow} end)

    # Tier 1: @everyone overwrite
    {e_allow, e_deny} =
      case Map.get(overwrite_map, everyone_role_id) do
        nil -> {0, 0}
        ow -> {parse_permissions(ow["allow"]), parse_permissions(ow["deny"])}
      end

    {allow, deny} = {e_allow, e_deny}
    after_everyone = (base &&& bnot(e_deny)) ||| e_allow

    # Tier 2: Role overwrites (merged via OR, then cascade over tier 1)
    {role_allow, role_deny} =
      Enum.reduce(overwrites, {0, 0}, fn ow, {ra, rd} ->
        ow_id = to_string(ow["id"])

        if ow_id != everyone_role_id and MapSet.member?(member_role_ids, ow_id) do
          {ra ||| parse_permissions(ow["allow"]), rd ||| parse_permissions(ow["deny"])}
        else
          {ra, rd}
        end
      end)

    # Role cascade overrides @everyone: role allows cancel @everyone denies, etc.
    allow = (allow &&& bnot(role_deny)) ||| role_allow
    deny = (deny &&& bnot(role_allow)) ||| role_deny

    after_roles = (base &&& bnot(deny)) ||| allow

    # Tier 3: Member-specific overwrite
    {member_allow, member_deny} =
      case Map.get(overwrite_map, user_id) do
        nil -> {0, 0}
        ow -> {parse_permissions(ow["allow"]), parse_permissions(ow["deny"])}
      end

    allow = (allow &&& bnot(member_deny)) ||| member_allow
    deny = (deny &&& bnot(member_allow)) ||| member_deny

    final = (base &&& bnot(deny)) ||| allow

    steps = [
      %{stage: :everyone_overwrite, allow: e_allow, deny: e_deny, result: after_everyone},
      %{stage: :role_overwrites, allow: role_allow, deny: role_deny, result: after_roles},
      %{stage: :member_overwrite, allow: member_allow, deny: member_deny, result: final}
    ]

    {final, steps}
  end

  # ── Helpers ───────────────────────────────────────────────────────

  defp get_user_id(%EDA.Member{user: %{id: id}}), do: to_string(id)
  defp get_user_id(%{"user" => %{"id" => id}}), do: to_string(id)
  defp get_user_id(%{"user_id" => id}), do: to_string(id)

  # Discord sends permissions as string integers in API v10
  defp parse_permissions(nil), do: 0
  defp parse_permissions(n) when is_integer(n), do: n
  defp parse_permissions(s) when is_binary(s), do: String.to_integer(s)
end
