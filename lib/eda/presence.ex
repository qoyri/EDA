defmodule EDA.Presence do
  @moduledoc """
  Presence and activity builder for Discord bots.

  Allows setting bot status (online, idle, dnd, invisible) and activities
  (playing, streaming, listening, watching, custom, competing).

  ## Examples

      # Build a presence with status and activity
      presence = EDA.Presence.new(
        status: :dnd,
        activities: [EDA.Presence.playing("Elixir")]
      )

      # Update at runtime
      EDA.set_presence(presence)

      # Convenience — just set an activity
      EDA.set_activity("Elixir", type: :playing)
  """

  @type status :: :online | :idle | :dnd | :invisible

  @type activity_type :: :playing | :streaming | :listening | :watching | :custom | :competing

  @type activity :: %{
          required(:name) => String.t(),
          required(:type) => activity_type(),
          optional(:url) => String.t()
        }

  @type t :: %__MODULE__{
          status: status(),
          activities: [activity()],
          afk: boolean(),
          since: integer() | nil
        }

  defstruct status: :online, activities: [], afk: false, since: nil

  @activity_type_map %{
    playing: 0,
    streaming: 1,
    listening: 2,
    watching: 3,
    custom: 4,
    competing: 5
  }

  @doc "Creates a Playing activity (type 0)."
  @spec playing(String.t()) :: activity()
  def playing(name), do: %{name: name, type: :playing}

  @doc "Creates a Streaming activity (type 1) with a Twitch/YouTube URL."
  @spec streaming(String.t(), String.t()) :: activity()
  def streaming(name, url), do: %{name: name, type: :streaming, url: url}

  @doc "Creates a Listening activity (type 2)."
  @spec listening(String.t()) :: activity()
  def listening(name), do: %{name: name, type: :listening}

  @doc "Creates a Watching activity (type 3)."
  @spec watching(String.t()) :: activity()
  def watching(name), do: %{name: name, type: :watching}

  @doc "Creates a Custom Status activity (type 4)."
  @spec custom(String.t()) :: activity()
  def custom(name), do: %{name: name, type: :custom}

  @doc "Creates a Competing activity (type 5)."
  @spec competing(String.t()) :: activity()
  def competing(name), do: %{name: name, type: :competing}

  @doc """
  Builds a `%Presence{}` struct from keyword options.

  ## Options

  - `:status` — `:online` | `:idle` | `:dnd` | `:invisible` (default `:online`)
  - `:activities` — list of activity maps from builder functions
  - `:afk` — boolean (default `false`)
  - `:since` — unix timestamp in milliseconds, or `nil`
  """
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    %__MODULE__{
      status: Keyword.get(opts, :status, :online),
      activities: Keyword.get(opts, :activities, []),
      afk: Keyword.get(opts, :afk, false),
      since: Keyword.get(opts, :since)
    }
  end

  @doc """
  Serializes a `%Presence{}` to the Discord gateway format.
  """
  @spec to_map(t()) :: map()
  def to_map(%__MODULE__{} = presence) do
    %{
      status: to_string(presence.status),
      activities: Enum.map(presence.activities, &serialize_activity/1),
      afk: presence.afk,
      since: presence.since
    }
  end

  # ── Reading someone else's presence ────────────────────────────────

  @platform_order [:desktop, :mobile, :web, :vr, :embedded]
  @platform_names Map.new(@platform_order, &{to_string(&1), &1})

  @typedoc """
  A platform a user has a session on.

  Discord documents `:desktop`, `:mobile`, `:web` and `:vr`. `:embedded` is not documented but
  is sent — a console or embedded session, seen live on 2026-09-23. A platform Discord adds
  later comes back as the string it sent, rather than being dropped.
  """
  @type platform :: :desktop | :mobile | :web | :vr | :embedded | String.t()

  @typedoc "The status of one session: what Discord sends per platform, never `:invisible`."
  @type session_status :: :online | :idle | :dnd

  @doc """
  The platforms a user has an active session on, in a stable order.

  Reads `client_status` from a `EDA.Event.PresenceUpdate`, a presence from `EDA.Cache`, or the
  `client_status` map itself. Discord sends one key per active session, so a user on two
  platforms gives two, and a user who is offline or invisible gives `[]` — invisibility is
  indistinguishable from being offline here, by design.

  A bot counts as a web session, which is why most of them show `[:web]`.

  ## Examples

      iex> EDA.Presence.platforms(%{"client_status" => %{"mobile" => "online", "desktop" => "idle"}})
      [:desktop, :mobile]

      iex> EDA.Presence.platforms(%EDA.Event.PresenceUpdate{client_status: %{web: :dnd}})
      [:web]

      iex> EDA.Presence.platforms(%{"status" => "offline"})
      []
  """
  @spec platforms(map() | EDA.Event.PresenceUpdate.t() | nil) :: [platform()]
  def platforms(presence) do
    case client_status(presence) do
      nil ->
        []

      status ->
        known = for p <- @platform_order, Map.has_key?(status, p), do: p
        known ++ Enum.sort(Map.keys(status) -- @platform_order)
    end
  end

  @doc """
  The user's status on one platform, or `nil` when they have no session there.

  ## Examples

      iex> EDA.Presence.status_on(%{"client_status" => %{"mobile" => "dnd"}}, :mobile)
      :dnd

      iex> EDA.Presence.status_on(%{"client_status" => %{"mobile" => "dnd"}}, :desktop)
      nil
  """
  @spec status_on(map() | EDA.Event.PresenceUpdate.t() | nil, platform()) ::
          session_status() | nil
  def status_on(presence, platform) do
    case client_status(presence) do
      %{^platform => value} when value in [:online, :idle, :dnd] -> value
      _ -> nil
    end
  end

  @doc """
  Whether the user has a session on that platform.

      iex> EDA.Presence.on?(%{"client_status" => %{"mobile" => "idle"}}, :mobile)
      true

      iex> EDA.Presence.on?(%{"client_status" => %{"mobile" => "idle"}}, :web)
      false
  """
  @spec on?(map() | EDA.Event.PresenceUpdate.t() | nil, platform()) :: boolean()
  def on?(presence, platform), do: status_on(presence, platform) != nil

  @doc "Whether the user has a desktop session. See `on?/2`."
  @spec desktop?(map() | EDA.Event.PresenceUpdate.t() | nil) :: boolean()
  def desktop?(presence), do: on?(presence, :desktop)

  @doc "Whether the user has a mobile session. See `on?/2`."
  @spec mobile?(map() | EDA.Event.PresenceUpdate.t() | nil) :: boolean()
  def mobile?(presence), do: on?(presence, :mobile)

  @doc """
  Whether the user has a web session. See `on?/2`.

  True for most bots: Discord counts a bot's gateway connection as a web session.
  """
  @spec web?(map() | EDA.Event.PresenceUpdate.t() | nil) :: boolean()
  def web?(presence), do: on?(presence, :web)

  @doc """
  Names a platform Discord sent, keeping an unknown one as its string.

      iex> EDA.Presence.platform("embedded")
      :embedded

      iex> EDA.Presence.platform("watch")
      "watch"
  """
  @spec platform(String.t()) :: platform()
  def platform(name) when is_binary(name), do: Map.get(@platform_names, name, name)

  @doc false
  # A presence's `status` as an atom; a value Discord adds later stays its string.
  def status_name(nil), do: nil
  def status_name(status) when is_atom(status), do: status

  def status_name(status) when is_binary(status),
    do:
      Map.get(
        %{"online" => :online, "idle" => :idle, "dnd" => :dnd, "offline" => :offline},
        status,
        status
      )

  @doc false
  # `client_status` with its platforms and statuses named.
  def parse_client_status(nil), do: nil

  def parse_client_status(status) when is_map(status) do
    Map.new(status, fn {platform, value} ->
      {if(is_binary(platform), do: platform(platform), else: platform), session_status(value)}
    end)
  end

  defp client_status(%EDA.Event.PresenceUpdate{client_status: status}), do: status

  defp client_status(%{"client_status" => status}) when is_map(status),
    do: parse_client_status(status)

  # A presence without client_status: the user is offline or invisible. Anything else is taken
  # for the client_status map itself, so a platform Discord adds later still reads.
  defp client_status(%{"status" => _}), do: nil
  defp client_status(%{"activities" => _}), do: nil
  defp client_status(%{"user" => _}), do: nil

  defp client_status(status) when is_map(status) and not is_struct(status),
    do: parse_client_status(status)

  defp client_status(_presence), do: nil

  defp session_status(status) when status in [:online, :idle, :dnd], do: status
  defp session_status("online"), do: :online
  defp session_status("idle"), do: :idle
  defp session_status("dnd"), do: :dnd
  defp session_status(other), do: other

  @doc false
  # Like every other conversion: nil stays nil, an integer passes, an unknown atom raises.
  def activity_type_value(nil), do: nil
  def activity_type_value(type) when is_integer(type), do: type

  def activity_type_value(type) when is_atom(type) do
    case @activity_type_map do
      %{^type => value} ->
        value

      _ ->
        raise ArgumentError,
              "unknown activity type #{inspect(type)}; known: " <>
                Enum.map_join(Map.keys(@activity_type_map), ", ", &inspect/1)
    end
  end

  defp serialize_activity(activity) do
    base = %{
      name: activity.name,
      type: activity_type_value(activity.type)
    }

    if url = Map.get(activity, :url) do
      Map.put(base, :url, url)
    else
      base
    end
  end
end
