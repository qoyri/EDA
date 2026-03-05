defmodule EDA do
  @moduledoc """
  EDA - Elixir Discord API

  A modern Discord library for Elixir, inspired by JDA (Java Discord API).

  ## Quick Start

  1. Add your bot token to config:

      config :eda,
        token: System.get_env("DISCORD_TOKEN"),
        intents: [:guilds, :guild_messages, :message_content]

  2. Create a consumer module:

      defmodule MyBot.Consumer do
        @behaviour EDA.Consumer

        def handle_event({:MESSAGE_CREATE, msg}) do
          if msg.content == "!ping" do
            EDA.API.Message.create(msg.channel_id, "Pong!")
          end
        end

        def handle_event(_), do: :ok
      end

  3. Register your consumer:

      config :eda, consumer: MyBot.Consumer

  4. Start your application and the bot will connect automatically!

  ## Features

  - WebSocket Gateway connection with automatic reconnection
  - REST API client with rate limiting
  - ETS-based caching for guilds, users, and channels
  - Simple consumer behaviour for handling events
  - Telemetry integration for observability
  """

  @doc """
  Returns the configured bot token.
  """
  @spec token() :: String.t() | nil
  def token do
    Application.get_env(:eda, :token)
  end

  @doc """
  Returns the configured gateway intents as a bitfield.
  """
  @spec intents() :: integer()
  def intents do
    Application.get_env(:eda, :intents, [:guilds])
    |> EDA.Gateway.Intents.to_bitfield()
  end

  @doc """
  Returns the configured consumer module.
  """
  @spec consumer() :: module() | nil
  def consumer do
    Application.get_env(:eda, :consumer)
  end

  @doc """
  Updates the bot's presence on all shards.

  Accepts an `%EDA.Presence{}` struct or a keyword list of options.

  ## Examples

      EDA.set_presence(EDA.Presence.new(status: :dnd, activities: [EDA.Presence.playing("Elixir")]))
      EDA.set_presence(status: :idle, activities: [EDA.Presence.watching("you")])
  """
  @spec set_presence(EDA.Presence.t() | keyword()) :: :ok
  def set_presence(%EDA.Presence{} = presence), do: broadcast_presence(presence)
  def set_presence(opts) when is_list(opts), do: broadcast_presence(EDA.Presence.new(opts))

  @doc """
  Sets the bot's activity on all shards.

  ## Options

  - `:type` — activity type (default `:playing`)
  - `:url` — stream URL (only for `:streaming`)
  - `:status` — status to set alongside the activity (default `:online`)

  ## Examples

      EDA.set_activity("Elixir", type: :playing)
      EDA.set_activity("on Twitch", type: :streaming, url: "https://twitch.tv/example")
  """
  @spec set_activity(String.t(), keyword()) :: :ok
  def set_activity(name, opts \\ []) do
    type = Keyword.get(opts, :type, :playing)
    status = Keyword.get(opts, :status, :online)

    activity =
      case type do
        :streaming -> EDA.Presence.streaming(name, Keyword.fetch!(opts, :url))
        :playing -> EDA.Presence.playing(name)
        :listening -> EDA.Presence.listening(name)
        :watching -> EDA.Presence.watching(name)
        :competing -> EDA.Presence.competing(name)
        :custom -> EDA.Presence.custom(name)
      end

    broadcast_presence(EDA.Presence.new(status: status, activities: [activity]))
  end

  @doc """
  Sets the bot's status on all shards without changing the activity.

  ## Examples

      EDA.set_status(:dnd)
      EDA.set_status(:invisible)
  """
  @spec set_status(EDA.Presence.status()) :: :ok
  def set_status(status) do
    broadcast_presence(EDA.Presence.new(status: status))
  end

  # ── Message History ────────────────────────────────────────────────

  @doc "Retrieves message history with automatic pagination."
  defdelegate message_history(channel_id, limit, opts \\ []),
    to: EDA.API.Message,
    as: :history

  @doc "Returns a lazy Stream of messages from a channel."
  defdelegate message_stream(channel_id, opts \\ []),
    to: EDA.API.Message,
    as: :stream

  @doc "Purges messages from a channel with auto-chunking."
  defdelegate purge_messages(channel_id, opts \\ []),
    to: EDA.API.Message,
    as: :purge

  # ── Member Chunking ──────────────────────────────────────────────────

  @doc "Requests all members for a guild (fire-and-forget, caches automatically)."
  @spec request_members(String.t() | integer(), keyword()) :: :ok
  defdelegate request_members(guild_id, opts \\ []), to: EDA.Gateway.MemberChunker, as: :request

  @doc "Requests all members and waits for completion."
  @spec await_members(String.t() | integer(), keyword()) :: {:ok, [map()]} | {:error, :timeout}
  defdelegate await_members(guild_id, opts \\ []), to: EDA.Gateway.MemberChunker, as: :await

  @doc "Searches members by username prefix (max 100 results)."
  @spec search_members(String.t() | integer(), String.t(), keyword()) ::
          {:ok, [map()]} | {:error, :timeout}
  defdelegate search_members(guild_id, query, opts \\ []),
    to: EDA.Gateway.MemberChunker,
    as: :search

  @doc "Fetches specific members by user IDs (max 100)."
  @spec fetch_members(String.t() | integer(), [String.t() | integer()], keyword()) ::
          {:ok, [map()]} | {:error, :timeout}
  defdelegate fetch_members(guild_id, user_ids, opts \\ []),
    to: EDA.Gateway.MemberChunker,
    as: :fetch

  # ── Event Collectors ─────────────────────────────────────────────────

  @doc """
  Awaits a `MESSAGE_CREATE` event matching the given filter.

  ## Examples

      {:ok, msg} = EDA.await_message(fn msg ->
        msg.channel_id == channel_id and msg.author["id"] == user_id
      end, timeout: 30_000)
  """
  @spec await_message((term() -> boolean()), keyword()) ::
          {:ok, term()} | {:ok, [term()]} | {:error, :timeout}
  def await_message(filter, opts \\ []) do
    EDA.Collector.await(:MESSAGE_CREATE, filter, opts)
  end

  @doc """
  Awaits a `MESSAGE_REACTION_ADD` event matching the given filter.

  ## Examples

      {:ok, reaction} = EDA.await_reaction(fn r ->
        r.message_id == msg_id and r.user_id != bot_id
      end, timeout: 60_000)
  """
  @spec await_reaction((term() -> boolean()), keyword()) ::
          {:ok, term()} | {:ok, [term()]} | {:error, :timeout}
  def await_reaction(filter, opts \\ []) do
    EDA.Collector.await(:MESSAGE_REACTION_ADD, filter, opts)
  end

  @doc """
  Awaits an `INTERACTION_CREATE` event matching the given filter.

  Useful for collecting button clicks, select menu selections, and modal submissions.

  ## Examples

      {:ok, interaction} = EDA.await_component(fn i ->
        EDA.Interaction.custom_id(i) == "confirm_btn"
      end, timeout: 30_000)
  """
  @spec await_component((term() -> boolean()), keyword()) ::
          {:ok, term()} | {:ok, [term()]} | {:error, :timeout}
  def await_component(filter, opts \\ []) do
    EDA.Collector.await(:INTERACTION_CREATE, filter, opts)
  end

  # ── Ready State ──────────────────────────────────────────────────────

  @doc """
  Blocks until all shards have finished loading their guilds.

  Returns `:ok` when the bot is fully ready, or `{:error, :timeout}` if the
  timeout expires. Uses OTP's native `GenServer.call` suspension — no scheduler
  is blocked.

  If the bot is already ready, returns `:ok` immediately.

  ## Options

    - `timeout` — maximum wait in milliseconds (default `60_000`)

  ## Examples

      EDA.await_ready()
      EDA.await_ready(30_000)
  """
  @spec await_ready(timeout()) :: :ok | {:error, :timeout}
  defdelegate await_ready(timeout \\ 60_000), to: EDA.Gateway.ReadyTracker

  @doc """
  Returns `true` if all shards have finished loading their guilds.

  Non-blocking — reads from `:persistent_term` (O(1)).
  """
  @spec ready?() :: boolean()
  defdelegate ready?(), to: EDA.Gateway.ReadyTracker

  # ── Internals ───────────────────────────────────────────────────────

  defp broadcast_presence(presence) do
    total = EDA.Gateway.ShardManager.total_shards()

    for shard_id <- 0..(total - 1) do
      via = {:via, Registry, {EDA.Gateway.Registry, shard_id}}
      WebSockex.cast(via, {:update_presence, presence})
    end

    :ok
  end

  @doc """
  Returns the configured shard mode.

  - `:auto` (default) — use Discord's recommended shard count
  - `integer` — fixed number of shards (e.g. `4` → shards 0..3)
  - `{Range.t(), integer}` — specific shards on this node (e.g. `{0..1, 4}`)
  """
  @spec shard_config() :: :auto | pos_integer() | {Range.t(), pos_integer()}
  def shard_config do
    Application.get_env(:eda, :shards, :auto)
  end

  @doc """
  Returns the configured gateway encoding.

  - `:etf` (default) — Erlang External Term Format (binary, efficient)
  - `:json` — JSON via Jason (text, useful for debugging)

  ## Configuration

      config :eda, gateway_encoding: :etf   # default
      config :eda, gateway_encoding: :json
  """
  @spec gateway_encoding() :: :etf | :json
  def gateway_encoding do
    Application.get_env(:eda, :gateway_encoding, :etf)
  end
end
