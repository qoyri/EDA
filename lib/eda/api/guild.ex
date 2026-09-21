defmodule EDA.API.Guild do
  @moduledoc """
  REST API endpoints for Discord guilds.

  All functions return `{:ok, result}` or `{:error, reason}`.
  """

  import EDA.HTTP.Client

  @doc "Gets a guild by ID."
  @spec get(String.t() | integer()) :: {:ok, map()} | {:error, term()}
  def get(guild_id) do
    EDA.HTTP.Client.get("/guilds/#{guild_id}")
  end

  @doc "Modifies a guild."
  @spec modify(String.t() | integer(), map(), keyword()) :: {:ok, map()} | {:error, term()}
  def modify(guild_id, payload, opts \\ []) do
    patch("/guilds/#{guild_id}", payload, opts)
  end

  @doc "Gets channels in a guild."
  @spec channels(String.t() | integer()) :: {:ok, [map()]} | {:error, term()}
  def channels(guild_id) do
    EDA.HTTP.Client.get("/guilds/#{guild_id}/channels")
  end

  @doc """
  Gets the number of members that would be pruned.

  Requires `MANAGE_GUILD` and `KICK_MEMBERS` — or `ADMINISTRATOR` when the guild has the
  `PRUNE_REQUIRES_ADMIN` feature, which its owner can turn on.
  """
  @spec prune_count(String.t() | integer(), keyword()) :: {:ok, map()} | {:error, term()}
  def prune_count(guild_id, opts \\ []) do
    EDA.HTTP.Client.get(with_query("/guilds/#{guild_id}/prune", opts, [:days, :include_roles]))
  end

  @prune_keys ~w(days compute_prune_count include_roles)a

  @doc """
  Begins a guild prune. **This kicks members.**

  Requires `MANAGE_GUILD` and `KICK_MEMBERS` — or `ADMINISTRATOR` when the guild has the
  `PRUNE_REQUIRES_ADMIN` feature, which its owner can turn on.

  ## Options

    * `:days` - inactivity threshold, 1–30, default 7
    * `:compute_prune_count` - whether the response reports how many were removed. Discord
      advises `false` on large guilds
    * `:include_roles` - role ids whose members are eligible; without it, members with any
      role are spared
    * `:reason` - audit log reason

  Accepts a keyword list or a map. An option this endpoint does not define raises
  `ArgumentError` and nothing is sent: Discord ignores an unrecognised body field, so `day: 30`
  would prune on the **default 7 days** — a destructive call doing more than it was asked.
  """
  @spec prune(String.t() | integer(), map() | keyword()) :: {:ok, map()} | {:error, term()}
  def prune(guild_id, opts) do
    {reason, body} = pop_prune_reason(opts)
    check_options!(body, @prune_keys, "EDA.API.Guild.prune/2")
    post("/guilds/#{guild_id}/prune", body, reason)
  end

  defp pop_prune_reason(opts) when is_list(opts) do
    {reason, rest} = Keyword.pop(opts, :reason)
    {if(reason, do: [reason: reason], else: []), Map.new(rest)}
  end

  defp pop_prune_reason(opts) when is_map(opts) do
    {reason, rest} = Map.pop(opts, :reason)
    {if(reason, do: [reason: reason], else: []), rest}
  end

  @doc "Gets invites for a guild."
  @spec invites(String.t() | integer()) :: {:ok, [map()]} | {:error, term()}
  def invites(guild_id) do
    EDA.HTTP.Client.get("/guilds/#{guild_id}/invites")
  end

  @doc """
  Gets the audit log for a guild.

  ## Options
  - `:user_id` - Filter by user who performed the action
  - `:action_type` - Filter by action type (integer or atom via `EDA.AuditLog.action_type/1`)
  - `:before` - Get entries before this entry ID
  - `:after` - Get entries after this entry ID
  - `:limit` - Number of entries (1-100, default 50)
  """
  @spec audit_log(String.t() | integer(), keyword()) ::
          {:ok, %{entries: [EDA.AuditLog.Entry.t()], users: [map()], webhooks: [map()]}}
          | {:error, term()}
  def audit_log(guild_id, opts \\ []) do
    opts = resolve_action_type(opts)

    case EDA.HTTP.Client.get(
           with_query("/guilds/#{guild_id}/audit-logs", opts, [
             :user_id,
             :action_type,
             :before,
             :after,
             :limit
           ])
         ) do
      {:ok, data} ->
        entries =
          (data["audit_log_entries"] || [])
          |> Enum.map(&EDA.AuditLog.Entry.from_raw/1)

        {:ok, %{entries: entries, users: data["users"] || [], webhooks: data["webhooks"] || []}}

      error ->
        error
    end
  end

  # ── Onboarding ─────────────────────────────────────────────────────

  @onboarding_keys ~w(prompts default_channel_ids enabled mode)a

  @doc """
  Gets a guild's onboarding: its prompts, default channels, and whether it is enabled.

  `GET /guilds/{guild_id}/onboarding`. `EDA.Onboarding.fetch/1` returns it as a struct.
  """
  @spec onboarding(String.t() | integer()) :: {:ok, map()} | {:error, term()}
  def onboarding(guild_id), do: EDA.HTTP.Client.get("/guilds/#{guild_id}/onboarding")

  @doc """
  Replaces a guild's onboarding. Requires `MANAGE_GUILD` and `MANAGE_ROLES`.

  `PUT /guilds/{guild_id}/onboarding`. Every field is optional, but `:prompts`, when given, is
  the **complete** list: a prompt left out is deleted. `EDA.Onboarding.save/2` is the safe way to
  change one prompt among several.

  ## Options

    * `:prompts` — `EDA.Onboarding.Prompt` structs or raw prompt maps. An option's emoji is
      sent as `emoji_id` / `emoji_name` / `emoji_animated` whichever form it came in: Discord
      ignores the `emoji` object it returns, so sending that back would clear the emoji
    * `:default_channel_ids` — channels every member joins
    * `:enabled` — enabling needs at least 7 default channels, 5 of them open to `@everyone`
    * `:mode` — `:default` or `:advanced`
    * `:reason` — audit log reason
  """
  @spec modify_onboarding(String.t() | integer(), keyword() | map()) ::
          {:ok, map()} | {:error, term()}
  def modify_onboarding(guild_id, opts) do
    {reason, body} = pop_prune_reason(opts)
    check_options!(body, @onboarding_keys, "EDA.API.Guild.modify_onboarding/2")

    body =
      body
      |> maybe_update(:prompts, fn prompts -> Enum.map(prompts, &prompt_payload/1) end)
      |> maybe_update(:mode, &EDA.Onboarding.mode_value!/1)

    put("/guilds/#{guild_id}/onboarding", body, reason)
  end

  defp maybe_update(body, key, fun) do
    case body do
      %{^key => value} -> Map.put(body, key, fun.(value))
      _ -> body
    end
  end

  defp prompt_payload(%EDA.Onboarding.Prompt{} = prompt),
    do: EDA.Onboarding.Prompt.to_payload(prompt)

  # A raw map, perhaps straight from onboarding/1: bring each option's emoji object into the
  # flat form Discord accepts.
  defp prompt_payload(%{} = prompt) do
    prompt = Map.new(prompt, fn {k, v} -> {to_string(k), v} end)

    case prompt do
      %{"options" => options} when is_list(options) ->
        %{prompt | "options" => Enum.map(options, &option_payload/1)}

      _ ->
        prompt
    end
  end

  defp option_payload(%EDA.Onboarding.Option{} = option),
    do: EDA.Onboarding.Option.to_payload(option)

  defp option_payload(%{} = option) do
    option = Map.new(option, fn {k, v} -> {to_string(k), v} end)

    case Map.pop(option, "emoji") do
      {%{} = emoji, rest} ->
        emoji = Map.new(emoji, fn {k, v} -> {to_string(k), v} end)

        rest
        |> Map.put_new("emoji_id", emoji["id"])
        |> Map.put_new("emoji_name", emoji["name"])
        |> Map.put_new("emoji_animated", emoji["animated"] || false)

      {_none, rest} ->
        rest
    end
  end
end
