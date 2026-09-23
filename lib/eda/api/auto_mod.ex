defmodule EDA.API.AutoMod do
  @moduledoc """
  REST API endpoints for Discord Auto Moderation rules.

  All functions return `{:ok, result}` or `{:error, reason}`.
  """

  import EDA.HTTP.Client

  @doc """
  Lists all Auto Moderation rules for a guild.
  """
  @spec list(String.t() | integer()) :: {:ok, [map()]} | {:error, term()}
  def list(guild_id) do
    get("/guilds/#{guild_id}/auto-moderation/rules")
  end

  @doc """
  Gets a single Auto Moderation rule by ID.


  """
  @spec get_rule(String.t() | integer(), String.t() | integer()) ::
          {:ok, map()} | {:error, term()}
  def get_rule(guild_id, rule_id) do
    get("/guilds/#{guild_id}/auto-moderation/rules/#{rule_id}")
  end

  @doc """
  Creates an Auto Moderation rule in a guild.

  ## Parameters

  - `guild_id` - The guild ID
  - `params` - Map with:
    - `:name` - Rule name (required, max 100 chars)
    - `:event_type` - Event type (required, 1 = message_send, 2 = member_update)
    - `:trigger_type` - Trigger type (required, see `EDA.AutoMod`)
    - `:trigger_metadata` - Trigger metadata map (optional, varies by trigger type)
    - `:actions` - List of action maps (required)
    - `:enabled` - Whether the rule is enabled (optional, default false)
    - `:exempt_roles` - List of exempt role IDs (optional, max 20)
    - `:exempt_channels` - List of exempt channel IDs (optional, max 50)


  """
  @spec create(String.t() | integer(), map()) :: {:ok, map()} | {:error, term()}
  def create(guild_id, params) do
    post("/guilds/#{guild_id}/auto-moderation/rules", encode_rule(params))
  end

  @doc """
  Modifies an Auto Moderation rule.

  Accepts the same parameters as `create/2` (all optional).

  """
  @spec modify(String.t() | integer(), String.t() | integer(), map()) ::
          {:ok, map()} | {:error, term()}
  def modify(guild_id, rule_id, params) do
    patch("/guilds/#{guild_id}/auto-moderation/rules/#{rule_id}", encode_rule(params))
  end

  @doc "Deletes an Auto Moderation rule."
  @spec delete_rule(String.t() | integer(), String.t() | integer()) :: :ok | {:error, term()}
  def delete_rule(guild_id, rule_id) do
    case delete("/guilds/#{guild_id}/auto-moderation/rules/#{rule_id}") do
      {:ok, _} -> :ok
      error -> error
    end
  end

  # The rule's enumerations may be given as atoms, and its actions and trigger metadata as
  # structs; Discord wants the integers and plain maps.
  defp encode_rule(params) do
    params
    |> Map.new()
    |> EDA.Enum.encode(
      event_type: &EDA.AutoMod.event_type_value/1,
      trigger_type: &EDA.AutoMod.trigger_type_value/1
    )
    |> update_present(:actions, &Enum.map(&1, fn action -> encode_action(action) end))
    |> update_present(:trigger_metadata, &encode_trigger_metadata/1)
  end

  defp encode_action(%EDA.AutoMod.Action{} = action), do: EDA.AutoMod.Action.to_map(action)

  defp encode_action(action) when is_map(action),
    do: EDA.Enum.encode(action, type: &EDA.AutoMod.Action.type_value/1)

  defp encode_trigger_metadata(%EDA.AutoMod.TriggerMetadata{} = meta),
    do: EDA.AutoMod.TriggerMetadata.to_map(meta)

  defp encode_trigger_metadata(%{} = meta) do
    Enum.reduce([:presets, "presets"], meta, fn key, acc ->
      case acc do
        %{^key => presets} when is_list(presets) ->
          Map.put(acc, key, Enum.map(presets, &EDA.AutoMod.TriggerMetadata.preset_value/1))

        _ ->
          acc
      end
    end)
  end

  defp update_present(map, key, fun) do
    Enum.reduce([key, Atom.to_string(key)], map, fn k, acc ->
      case acc do
        %{^k => value} when not is_nil(value) -> Map.put(acc, k, fun.(value))
        _ -> acc
      end
    end)
  end
end
