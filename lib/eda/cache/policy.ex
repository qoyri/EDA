defmodule EDA.Cache.Policy do
  @moduledoc """
  Cache admission policy behaviour and dispatcher.

  Controls whether incoming Discord data should be cached or skipped.
  Used by cache modules to gate writes on the hot path.

  ## Policy values

  - `:all` (default) — cache everything
  - `:none` — cache nothing
  - `module` — a module implementing the `EDA.Cache.Policy` behaviour
  - `fn/3` — an anonymous function `fn entity, key, value -> :cache | :skip end`

  `value` is the struct about to be cached: an `EDA.Channel`, an `EDA.Member`, and so on.

  ## Example

      config :eda,
        cache: [
          presences: [policy: :none],
          channels: [policy: fn _entity, _key, ch ->
            if ch.type in [:guild_text, :guild_voice, :guild_announcement],
              do: :cache,
              else: :skip
          end]
        ]
  """

  @type entity :: :guild | :user | :channel | :member | :role | :voice_state | :presence
  @type decision :: :cache | :skip

  @doc "Decides whether the given entity should be cached."
  @callback should_cache?(entity(), key :: term(), value :: struct()) :: decision()

  @doc """
  Dispatches a policy check.

  Returns `:cache` or `:skip` depending on the configured policy.
  """
  @spec check(term(), entity(), term(), map()) :: decision()
  def check(:all, _entity, _key, _value), do: :cache
  def check(nil, _entity, _key, _value), do: :cache
  def check(:none, _entity, _key, _value), do: :skip
  def check(fun, entity, key, value) when is_function(fun, 3), do: fun.(entity, key, value)
  def check(mod, entity, key, value) when is_atom(mod), do: mod.should_cache?(entity, key, value)
end
