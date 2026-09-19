defmodule EDA.Cache.Config do
  @moduledoc """
  Resolves cache configuration at startup and stores it in `:persistent_term` for O(1) access.

  Called once by `EDA.Cache.Supervisor` before cache processes start.

  ## Example

      config :eda,
        cache: [
          guilds: [],
          users: [max_size: 100_000],
          members: [policy: :none],
          presences: [policy: :none],
          channels: [policy: fn _entity, _key, ch ->
            if ch["type"] in [0, 2, 5], do: :cache, else: :skip
          end]
        ]
  """

  @defaults %{policy: :all, max_size: nil}
  @cache_keys [:guilds, :users, :channels, :members, :roles, :voice_states, :presences]

  @doc "Resolves application config and stores in persistent_term. Idempotent."
  @spec setup() :: :ok
  def setup do
    adapter = Application.get_env(:eda, :cache_adapter, EDA.Cache.Adapter.ETS)
    :persistent_term.put(:eda_cache_adapter, adapter)

    app_config = Application.get_env(:eda, :cache, [])

    for key <- @cache_keys do
      opts = Keyword.get(app_config, key, [])
      resolved = Map.merge(@defaults, Map.new(opts))
      :persistent_term.put({:eda_cache_config, key}, resolved)
    end

    :ok
  end

  @doc "Returns the full config map for a cache."
  @spec get(atom()) :: map()
  def get(cache_name) do
    :persistent_term.get({:eda_cache_config, cache_name}, @defaults)
  end

  @doc "Returns the policy for a cache."
  @spec policy(atom()) :: term()
  def policy(cache_name), do: get(cache_name).policy

  @doc "Returns the max_size for a cache, or nil if unlimited."
  @spec max_size(atom()) :: non_neg_integer() | nil
  def max_size(cache_name), do: get(cache_name).max_size

  @doc "Returns all cache key names."
  @spec cache_keys() :: [atom()]
  def cache_keys, do: @cache_keys

  @doc """
  The configured storage adapter.

  See `EDA.Cache.Adapter`. Defaults to `EDA.Cache.Adapter.ETS`.
  """
  @spec adapter() :: module()
  def adapter, do: EDA.Cache.Adapter.current()
end
