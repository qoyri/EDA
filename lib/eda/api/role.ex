defmodule EDA.API.Role do
  @moduledoc """
  REST API endpoints for Discord guild roles.

  All functions return `{:ok, result}` or `{:error, reason}`.
  """

  import EDA.HTTP.Client

  @doc "Gets roles for a guild."
  @spec list(String.t() | integer()) :: {:ok, [map()]} | {:error, term()}
  def list(guild_id) do
    EDA.HTTP.Client.get("/guilds/#{guild_id}/roles")
  end

  @doc """
  Gets the number of members carrying each role in a guild.

  Returns a map of role ID to member count.

  Two things to know, both confirmed against a live guild (2026-09-19):

    * the **`@everyone` role is absent** from the result — its ID equals the guild ID,
      and every member carries it, so Discord omits it. Expect one fewer entry than
      `list/1` returns;
    * the counts **overlap**. A member holding three roles is counted in all three, so
      the values sum to more than the guild's `member_count` (2739 against 528 on the
      guild probed).

  ## Examples

      {:ok, counts} = EDA.API.Role.member_counts(guild_id)
      #=> {:ok, %{"938496731396599808" => 179, "964090281647542342" => 272}}

      Map.get(counts, role_id, 0)
  """
  @spec member_counts(String.t() | integer()) ::
          {:ok, %{String.t() => non_neg_integer()}} | {:error, term()}
  def member_counts(guild_id) do
    EDA.HTTP.Client.get("/guilds/#{guild_id}/roles/member-counts")
  end

  @doc "Creates a role in a guild."
  @spec create(String.t() | integer(), keyword() | map(), keyword()) ::
          {:ok, map()} | {:error, term()}
  def create(guild_id, params \\ [], opts \\ []) do
    body = if is_list(params), do: Map.new(params), else: params
    post("/guilds/#{guild_id}/roles", body, opts)
  end

  @doc "Modifies a guild role."
  @spec modify(String.t() | integer(), String.t() | integer(), map(), keyword()) ::
          {:ok, map()} | {:error, term()}
  def modify(guild_id, role_id, payload, opts \\ []) do
    patch("/guilds/#{guild_id}/roles/#{role_id}", payload, opts)
  end

  @doc "Deletes a guild role."
  @spec delete(String.t() | integer(), String.t() | integer(), keyword()) ::
          :ok | {:error, term()}
  def delete(guild_id, role_id, opts \\ []) do
    case EDA.HTTP.Client.delete("/guilds/#{guild_id}/roles/#{role_id}", opts) do
      {:ok, _} -> :ok
      error -> error
    end
  end

  @doc "Modifies guild role positions."
  @spec modify_positions(String.t() | integer(), [map()]) ::
          {:ok, [map()]} | {:error, term()}
  def modify_positions(guild_id, positions) do
    patch("/guilds/#{guild_id}/roles", positions)
  end
end
