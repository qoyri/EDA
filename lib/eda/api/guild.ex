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

  @doc "Gets the number of members that would be pruned."
  @spec prune_count(String.t() | integer(), keyword()) :: {:ok, map()} | {:error, term()}
  def prune_count(guild_id, opts \\ []) do
    EDA.HTTP.Client.get(with_query("/guilds/#{guild_id}/prune", opts, [:days, :include_roles]))
  end

  @prune_keys ~w(days compute_prune_count include_roles)a

  @doc """
  Begins a guild prune. **This kicks members.**

  ## Options

    * `:days` - inactivity threshold, 1–30, default 7
    * `:compute_prune_count` - whether the response reports how many were removed. Discord
      advises `false` on large guilds
    * `:include_roles` - role ids whose members are eligible; without it, members with any
      role are spared
    * `:reason` - audit log reason

  Accepts a keyword list or a map. An option this endpoint does not define is reported with
  a warning: Discord ignores an unrecognised body field, so `day: 30` prunes on the **default
  7 days** instead — a destructive call doing more than it was asked. EDA 0.5 will refuse it.
  """
  @spec prune(String.t() | integer(), map() | keyword()) :: {:ok, map()} | {:error, term()}
  def prune(guild_id, opts) do
    {reason, body} = pop_prune_reason(opts)
    check_options(body, @prune_keys, "EDA.API.Guild.prune/2")
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
end
