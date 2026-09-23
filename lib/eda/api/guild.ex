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
    payload =
      EDA.Enum.encode(Map.new(payload),
        verification_level: &EDA.Guild.verification_level_value/1,
        default_message_notifications: &EDA.Guild.default_message_notifications_value/1,
        explicit_content_filter: &EDA.Guild.explicit_content_filter_value/1
      )

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

  # What an audit log response carries besides its entries: the objects they point at.
  @audit_log_lists ~w(users webhooks application_commands auto_moderation_rules
                      guild_scheduled_events integrations threads)

  @doc """
  Gets the audit log for a guild.

  ## Options
  - `:user_id` - Filter by user who performed the action
  - `:action_type` - Filter by action type (integer or atom via `EDA.AuditLog.action_type/1`)
  - `:before` - Get entries before this entry ID
  - `:after` - Get entries after this entry ID
  - `:limit` - Number of entries (1-100, default 50)

  Besides the entries, the result holds what they point at, as Discord sends it: `users`,
  `webhooks`, `application_commands`, `auto_moderation_rules`, `guild_scheduled_events`,
  `integrations` and `threads` — so an entry's target can be named without another request.
  """
  @spec audit_log(String.t() | integer(), keyword()) ::
          {:ok,
           %{
             entries: [EDA.AuditLog.Entry.t()],
             users: [map()],
             webhooks: [map()],
             application_commands: [map()],
             auto_moderation_rules: [map()],
             guild_scheduled_events: [map()],
             integrations: [map()],
             threads: [map()]
           }}
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

        referenced = Map.new(@audit_log_lists, &{String.to_atom(&1), data[&1] || []})
        {:ok, Map.put(referenced, :entries, entries)}

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

  # ── Integrations ───────────────────────────────────────────────────

  @doc """
  Lists a guild's integrations — Twitch, YouTube, and bot or OAuth2 applications. Requires
  `MANAGE_GUILD`. Discord returns at most 50; `EDA.Integration.from_raw/1` parses each.
  """
  @spec integrations(String.t() | integer()) :: {:ok, [map()]} | {:error, term()}
  def integrations(guild_id), do: EDA.HTTP.Client.get("/guilds/#{guild_id}/integrations")

  @doc """
  Deletes a guild integration, with its webhooks — and **kicks its bot**, if it has one. Requires
  `MANAGE_GUILD`.

  ## Options

    * `:reason` — audit log reason
  """
  @spec delete_integration(String.t() | integer(), String.t() | integer(), keyword()) ::
          :ok | {:error, term()}
  def delete_integration(guild_id, integration_id, opts \\ []) do
    check_options!(opts, [:reason], "EDA.API.Guild.delete_integration/3")

    case EDA.HTTP.Client.delete("/guilds/#{guild_id}/integrations/#{integration_id}", opts) do
      {:ok, _} -> :ok
      error -> error
    end
  end

  # ── Welcome screen, preview, vanity URL ────────────────────────────

  @doc """
  Gets a guild's welcome screen: its description and the channels it recommends. Needs
  `MANAGE_GUILD` while the welcome screen is disabled.
  """
  @spec welcome_screen(String.t() | integer()) :: {:ok, map()} | {:error, term()}
  def welcome_screen(guild_id), do: EDA.HTTP.Client.get("/guilds/#{guild_id}/welcome-screen")

  @doc """
  Modifies a guild's welcome screen. Requires `MANAGE_GUILD`. Every field is optional.

  ## Options

    * `:enabled` — whether the welcome screen is shown
    * `:description` — the server description it shows
    * `:welcome_channels` — the channels it recommends, each
      `%{channel_id: ..., description: ..., emoji_id: ..., emoji_name: ...}`
    * `:reason` — audit log reason
  """
  @spec modify_welcome_screen(String.t() | integer(), keyword() | map()) ::
          {:ok, map()} | {:error, term()}
  def modify_welcome_screen(guild_id, opts) do
    {reason, body} = pop_prune_reason(opts)

    check_options!(
      body,
      [:enabled, :description, :welcome_channels],
      "EDA.API.Guild.modify_welcome_screen/2"
    )

    patch("/guilds/#{guild_id}/welcome-screen", body, reason)
  end

  @doc """
  Gets a guild's preview: name, icon, emojis, stickers, features and approximate counts. For a
  guild the bot is not in, the guild must be discoverable.
  """
  @spec preview(String.t() | integer()) :: {:ok, map()} | {:error, term()}
  def preview(guild_id), do: EDA.HTTP.Client.get("/guilds/#{guild_id}/preview")

  @doc """
  Gets a guild's vanity invite and how many times it was used, `%{"code" => ..., "uses" => ...}`.
  Requires `MANAGE_GUILD` and the `VANITY_URL` feature. The code alone is on the guild object as
  `vanity_url_code`; this route is the only way to the use count.
  """
  @spec vanity_url(String.t() | integer()) :: {:ok, map()} | {:error, term()}
  def vanity_url(guild_id), do: EDA.HTTP.Client.get("/guilds/#{guild_id}/vanity-url")

  @doc "Lists the voice regions available to a guild, VIP ones included. See `EDA.API.Voice.regions/0`."
  @spec voice_regions(String.t() | integer()) :: {:ok, [map()]} | {:error, term()}
  def voice_regions(guild_id), do: EDA.HTTP.Client.get("/guilds/#{guild_id}/regions")

  # ── Widget ─────────────────────────────────────────────────────────

  @doc "Gets a guild's widget settings, `%{\"enabled\" => ..., \"channel_id\" => ...}`. Requires `MANAGE_GUILD`."
  @spec widget_settings(String.t() | integer()) :: {:ok, map()} | {:error, term()}
  def widget_settings(guild_id), do: EDA.HTTP.Client.get("/guilds/#{guild_id}/widget")

  @doc """
  Modifies a guild's widget settings. Requires `MANAGE_GUILD`.

  ## Options

    * `:enabled` — whether the widget is on
    * `:channel_id` — the channel its invite leads to, or `nil`
    * `:reason` — audit log reason
  """
  @spec modify_widget(String.t() | integer(), keyword() | map()) ::
          {:ok, map()} | {:error, term()}
  def modify_widget(guild_id, opts) do
    {reason, body} = pop_prune_reason(opts)
    check_options!(body, [:enabled, :channel_id], "EDA.API.Guild.modify_widget/2")
    patch("/guilds/#{guild_id}/widget", body, reason)
  end

  @doc """
  Gets a guild's public widget: its name, online members and instant invite. Needs the widget to
  be enabled, and nothing else — no permission, no authentication.
  """
  @spec widget(String.t() | integer()) :: {:ok, map()} | {:error, term()}
  def widget(guild_id), do: EDA.HTTP.Client.get("/guilds/#{guild_id}/widget.json")

  @widget_styles ~w(shield banner1 banner2 banner3 banner4)a

  @doc """
  The URL of a guild's widget image, a PNG anyone can load while the widget is enabled — for a
  website or a README. Builds the URL; nothing is fetched.

  `style` is one of `:shield` (the default), `:banner1` to `:banner4`.

      iex> EDA.API.Guild.widget_image_url("1", :banner2)
      "https://discord.com/api/v10/guilds/1/widget.png?style=banner2"
  """
  @spec widget_image_url(String.t() | integer(), atom()) :: String.t()
  def widget_image_url(guild_id, style \\ :shield) when style in @widget_styles do
    "https://discord.com/api/v10/guilds/#{guild_id}/widget.png?style=#{style}"
  end

  # ── Incident actions ───────────────────────────────────────────────

  @doc """
  Pauses invites or direct messages in a guild during a raid, for up to 24 hours. Requires
  `MANAGE_GUILD`.

  ## Options

    * `:invites_disabled_until` — a `DateTime` (or ISO8601 string) at most 24 hours ahead, or
      `nil` to allow invites again
    * `:dms_disabled_until` — the same, for direct messages between members

  Returns the guild's incidents data.

      until = DateTime.add(DateTime.utc_now(), 3600)
      EDA.API.Guild.modify_incident_actions(guild_id, invites_disabled_until: until)
  """
  @spec modify_incident_actions(String.t() | integer(), keyword()) ::
          {:ok, map()} | {:error, term()}
  def modify_incident_actions(guild_id, opts) do
    check_options!(
      opts,
      [:invites_disabled_until, :dms_disabled_until],
      "EDA.API.Guild.modify_incident_actions/2"
    )

    body = Map.new(opts, fn {key, value} -> {key, incident_until!(key, value)} end)
    put("/guilds/#{guild_id}/incident-actions", body)
  end

  defp incident_until!(_key, nil), do: nil
  defp incident_until!(_key, iso) when is_binary(iso), do: iso

  defp incident_until!(key, %DateTime{} = until) do
    if DateTime.diff(until, DateTime.utc_now()) > 24 * 3600 do
      raise ArgumentError, "#{key} is at most 24 hours ahead, got #{DateTime.to_iso8601(until)}"
    end

    DateTime.to_iso8601(until)
  end
end
