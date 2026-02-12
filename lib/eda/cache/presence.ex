defmodule EDA.Cache.Presence do
  @moduledoc """
  ETS-based cache for Discord presences.

  Tracks user status (online/idle/dnd/offline) and activities per guild.
  Keyed by `{guild_id, user_id}`.

  Requires the `guild_presences` privileged intent.
  Automatically populated from GUILD_CREATE and PRESENCE_UPDATE events.
  """

  use GenServer

  @table :eda_presences

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @doc """
  Gets a user's presence in a guild.
  """
  @spec get(String.t() | integer(), String.t() | integer()) :: map() | nil
  def get(guild_id, user_id) do
    key = {to_string(guild_id), to_string(user_id)}

    case :ets.lookup(@table, key) do
      [{_, presence}] -> presence
      [] -> nil
    end
  end

  @doc """
  Gets all presences for a guild.
  """
  @spec for_guild(String.t() | integer()) :: [map()]
  def for_guild(guild_id) do
    guild_id = to_string(guild_id)

    :ets.match_object(@table, {{guild_id, :_}, :_})
    |> Enum.map(fn {_, presence} -> presence end)
  end

  @doc """
  Creates or updates a presence.
  """
  @spec upsert(String.t(), map()) :: :ok
  def upsert(guild_id, data) do
    guild_id = to_string(guild_id)

    user_id =
      case data["user"] do
        %{"id" => id} -> to_string(id)
        _ -> to_string(data["user_id"])
      end

    key = {guild_id, user_id}
    presence = Map.put(data, "guild_id", guild_id)
    :ets.insert(@table, {key, presence})
    :ok
  end

  @doc """
  Removes all presences for a guild.
  """
  @spec delete_guild(String.t() | integer()) :: :ok
  def delete_guild(guild_id) do
    guild_id = to_string(guild_id)
    :ets.match_delete(@table, {{guild_id, :_}, :_})
    :ok
  end

  @doc """
  Returns the total number of cached presences.
  """
  @spec count() :: non_neg_integer()
  def count do
    :ets.info(@table, :size)
  end

  @impl true
  def init(_opts) do
    table = :ets.new(@table, [:set, :public, :named_table, read_concurrency: true])
    {:ok, %{table: table}}
  end
end
