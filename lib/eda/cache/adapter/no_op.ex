defmodule EDA.Cache.Adapter.NoOp do
  @moduledoc """
  An `EDA.Cache.Adapter` that stores nothing.

  Every write is discarded and every read misses, so `EDA.Cache.get_guild/1` and friends
  always return `nil` and the `fetch_*` functions fall through to REST on every call.

      config :eda, cache_adapter: EDA.Cache.Adapter.NoOp

  Useful for a memory-constrained bot that would rather pay the HTTP cost, for a stateless
  worker that keeps no guild state, and in tests where cached state leaking between cases
  is a nuisance.

  > #### Prefer a policy for partial caching {: .tip}
  >
  > This turns off *all* caches. To keep some entities and drop others, leave the ETS
  > adapter in place and use a per-entity admission policy instead — see `EDA.Cache`:
  >
  >     config :eda, cache: [presences: [policy: :none], members: [policy: :none]]
  """

  @behaviour EDA.Cache.Adapter

  @impl true
  def init(_table, _opts), do: :ok

  @impl true
  def get(_table, _key), do: nil

  @impl true
  def put(_table, _key, _value), do: :ok

  @impl true
  def delete(_table, _key), do: :ok

  @impl true
  def all(_table), do: []

  @impl true
  def count(_table), do: 0

  @impl true
  def match_prefix(_table, _prefix), do: []

  @impl true
  def delete_prefix(_table, _prefix), do: []
end
