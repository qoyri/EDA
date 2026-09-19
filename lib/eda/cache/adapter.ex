defmodule EDA.Cache.Adapter do
  @moduledoc """
  Storage backend for EDA's caches.

  EDA's caches are split in two: this behaviour owns *where* entities are stored, while
  `EDA.Cache.Guild` and friends own *which* ones are stored and *how many* — admission
  policy (`EDA.Cache.Policy`), size limits and eviction (`EDA.Cache.Evictor`), and
  telemetry.

  That split is deliberate. Nostrum also makes its caches swappable, but each of its
  backends reimplements the cache wholesale, and none of them offers admission filtering
  or bounded memory. Here those live **above** the adapter, so every backend — including
  one you write yourself — inherits them for free.

  ## Configuration

      config :eda, cache_adapter: EDA.Cache.Adapter.ETS   # default
      config :eda, cache_adapter: EDA.Cache.Adapter.NoOp  # store nothing

  The adapter is resolved once at startup by `EDA.Cache.Config` and read from
  `:persistent_term`, so lookups on the hot path cost nothing.

  ## Key shapes

  Caches use one of two key shapes, and an adapter must support both:

    * a flat binary id — guilds and users;
    * a composite `{guild_id, id}` tuple — channels, members, roles, presences and voice
      states. `match_prefix/2` and `delete_prefix/2` exist to serve "everything in this
      guild" without scanning the whole table.

  Channels and roles additionally keep a secondary index table mapping a bare id back to
  its guild, so they can be looked up without knowing the guild. An index is just another
  table from the adapter's point of view — `put/3` and `get/2` serve it.

  ## Writing an adapter

  Implement every callback. `init/2` is called once per table at startup; the rest must be
  safe to call from any process, since EDA reads caches directly from the caller rather
  than through a GenServer.

      defmodule MyApp.RedisCache do
        @behaviour EDA.Cache.Adapter
        # ...
      end
  """

  @typedoc "The logical table name, e.g. `:eda_guilds`."
  @type table :: atom()

  @typedoc "A flat id or a `{guild_id, id}` tuple."
  @type key :: term()

  @typedoc "A cached entity, as a raw string-keyed map, or an index value."
  @type value :: term()

  @doc "Prepares a table. Called once per table at startup."
  @callback init(table(), keyword()) :: :ok

  @doc "Fetches one value, or `nil`."
  @callback get(table(), key()) :: value() | nil

  @doc "Stores a value, replacing any existing one."
  @callback put(table(), key(), value()) :: :ok

  @doc "Removes one key. Removing an absent key is not an error."
  @callback delete(table(), key()) :: :ok

  @doc "Every value in the table."
  @callback all(table()) :: [value()]

  @doc "How many entries the table holds."
  @callback count(table()) :: non_neg_integer()

  @doc """
  Every value whose key is `{prefix, _}`.

  Only meaningful for composite-key tables; a flat-key table may return `[]`.
  """
  @callback match_prefix(table(), term()) :: [value()]

  @doc """
  Removes every entry whose key is `{prefix, _}`, returning the second element of each
  key removed.

  The return value lets a cache clean up its secondary index without a second scan.
  """
  @callback delete_prefix(table(), term()) :: [term()]

  @doc """
  The configured adapter module.

  Resolved at startup into `:persistent_term`; falls back to `EDA.Cache.Adapter.ETS`.
  """
  @spec current() :: module()
  def current do
    :persistent_term.get(:eda_cache_adapter, EDA.Cache.Adapter.ETS)
  end
end
