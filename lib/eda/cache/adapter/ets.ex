defmodule EDA.Cache.Adapter.ETS do
  @moduledoc """
  Default `EDA.Cache.Adapter`: named public ETS tables, read-optimised.

  Tables are created once at startup and read directly by the calling process, so a cache
  hit never crosses a process boundary.

  This is what EDA has always done; it is now behind the adapter contract so other
  backends can replace it without touching admission policy, eviction or telemetry.
  """

  @behaviour EDA.Cache.Adapter

  @impl true
  def init(table, _opts) do
    if :ets.whereis(table) == :undefined do
      :ets.new(table, [:set, :public, :named_table, read_concurrency: true])
    end

    :ok
  end

  @impl true
  def get(table, key) do
    case :ets.lookup(table, key) do
      [{_key, value}] -> value
      [] -> nil
    end
  end

  @impl true
  def put(table, key, value) do
    :ets.insert(table, {key, value})
    :ok
  end

  @impl true
  def delete(table, key) do
    :ets.delete(table, key)
    :ok
  end

  @impl true
  def all(table) do
    table
    |> :ets.tab2list()
    |> Enum.map(fn {_key, value} -> value end)
  end

  @impl true
  def count(table) do
    case :ets.info(table, :size) do
      :undefined -> 0
      size -> size
    end
  end

  @impl true
  def match_prefix(table, prefix) do
    table
    |> :ets.match_object({{prefix, :_}, :_})
    |> Enum.map(fn {_key, value} -> value end)
  end

  @impl true
  def delete_prefix(table, prefix) do
    removed =
      table
      |> :ets.match({{prefix, :"$1"}, :_})
      |> List.flatten()

    :ets.match_delete(table, {{prefix, :_}, :_})

    removed
  end
end
