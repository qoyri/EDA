defmodule EDA.Member do
  @moduledoc "Represents a Discord guild member."
  use EDA.Event.Access

  defstruct [
    :user,
    :nick,
    :avatar,
    :banner,
    :bio,
    :roles,
    :joined_at,
    :premium_since,
    :deaf,
    :mute,
    :pending,
    :permissions,
    :communication_disabled_until
  ]

  @type t :: %__MODULE__{
          user: EDA.User.t() | nil,
          nick: String.t() | nil,
          avatar: String.t() | nil,
          banner: String.t() | nil,
          bio: String.t() | nil,
          roles: [String.t()] | nil,
          joined_at: String.t() | nil,
          premium_since: String.t() | nil,
          deaf: boolean() | nil,
          mute: boolean() | nil,
          pending: boolean() | nil,
          permissions: String.t() | nil,
          communication_disabled_until: String.t() | nil
        }

  @spec from_raw(map()) :: t()
  def from_raw(raw) when is_map(raw) do
    %__MODULE__{
      user: parse_user(raw["user"]),
      nick: raw["nick"],
      avatar: raw["avatar"],
      banner: raw["banner"],
      bio: raw["bio"],
      roles: raw["roles"],
      joined_at: raw["joined_at"],
      premium_since: raw["premium_since"],
      deaf: raw["deaf"],
      mute: raw["mute"],
      pending: raw["pending"],
      permissions: raw["permissions"],
      communication_disabled_until: raw["communication_disabled_until"]
    }
  end

  defp parse_user(nil), do: nil
  defp parse_user(raw) when is_map(raw), do: EDA.User.from_raw(raw)

  @doc """
  When the member's timeout ends, or `nil` if they have never been timed out.

  May return a date in the **past**, in which case the timeout has expired — Discord
  leaves the field populated. Use `timed_out?/1` to ask whether it is currently active.
  JDA draws the same distinction with `getTimeOutEnd()` / `isTimedOut()`.

  Accepts a struct or a raw member map.

  ## Examples

      iex> EDA.Member.time_out_end(%EDA.Member{communication_disabled_until: "2099-01-01T00:00:00Z"})
      ~U[2099-01-01 00:00:00Z]

      iex> EDA.Member.time_out_end(%EDA.Member{})
      nil
  """
  @spec time_out_end(t() | map()) :: DateTime.t() | nil
  def time_out_end(member)

  def time_out_end(%__MODULE__{communication_disabled_until: until}), do: parse_timestamp(until)
  def time_out_end(%{"communication_disabled_until" => until}), do: parse_timestamp(until)
  def time_out_end(_member), do: nil

  @doc """
  Returns `true` while the member is currently timed out.

  Accepts a struct or a raw member map.

  > #### Not reflected in permissions {: .warning}
  >
  > Discord removes every permission except `VIEW_CHANNEL` and `READ_MESSAGE_HISTORY`
  > from a timed-out member, but `EDA.Permission.in_channel/3` does **not** account for
  > it — neither does JDA's `hasPermission`. Check this yourself before gating an action
  > on a permission.

  ## Examples

      iex> EDA.Member.timed_out?(%EDA.Member{communication_disabled_until: "2099-01-01T00:00:00Z"})
      true

      iex> EDA.Member.timed_out?(%EDA.Member{communication_disabled_until: "2020-01-01T00:00:00Z"})
      false

      iex> EDA.Member.timed_out?(%EDA.Member{})
      false
  """
  @spec timed_out?(t() | map()) :: boolean()
  def timed_out?(member) do
    case time_out_end(member) do
      nil -> false
      until -> DateTime.compare(until, DateTime.utc_now()) == :gt
    end
  end

  defp parse_timestamp(nil), do: nil

  defp parse_timestamp(value) when is_binary(value) do
    case DateTime.from_iso8601(value) do
      {:ok, dt, _offset} -> dt
      {:error, _reason} -> nil
    end
  end

  defp parse_timestamp(%DateTime{} = value), do: value
  defp parse_timestamp(_value), do: nil

  # ── Entity Manager ──

  use EDA.Entity

  @doc """
  Fetches a member by guild ID and user ID. Checks cache first, falls back to REST.
  """
  @spec fetch_member(String.t() | integer(), String.t() | integer()) ::
          {:ok, t()} | {:error, term()}
  def fetch_member(guild_id, user_id) do
    case EDA.Cache.get_member(guild_id, user_id) do
      nil -> EDA.API.Member.get(guild_id, user_id) |> parse_response()
      raw -> {:ok, from_raw(raw)}
    end
  end

  @doc """
  Modifies a guild member.

  ## Options

  - `:reason` - Audit log reason
  """
  @spec modify(String.t() | integer(), t() | String.t() | integer(), map(), keyword()) ::
          {:ok, t()} | {:error, term()}
  def modify(guild_id, member, payload, opts \\ [])

  def modify(guild_id, %__MODULE__{user: %{id: uid}}, payload, opts),
    do: modify(guild_id, uid, payload, opts)

  def modify(guild_id, user_id, payload, opts)
      when (is_binary(user_id) or is_integer(user_id)) and is_map(payload) do
    EDA.API.Member.modify(guild_id, user_id, payload, opts) |> parse_response()
  end

  @doc """
  Modifies the bot's own member in a guild — its per-guild profile.

  Returns a `t:t/0`. Takes the same options as `EDA.API.Member.modify_me/2`: `:nick`,
  `:avatar`, `:banner`, `:bio` and `:reason`. `:avatar` and `:banner` accept a path, raw
  image bytes or a data URI, and `nil` clears the field so the account-wide value shows
  again.

  Only `:nick` needs a permission (`CHANGE_NICKNAME`); the appearance fields need none.

      EDA.Member.modify_me(guild_id, nick: "EDA", avatar: "priv/avatar.png")

  Fields you leave out are untouched, so setting a bio alone keeps the avatar and banner.

  `:bio` comes back on **this** response but not on a later `fetch_member/2`: Discord omits
  it from the guild member object. Read it from the struct this returns, or keep your own
  copy — a round trip will not give it back.
  """
  @spec modify_me(String.t() | integer(), keyword() | map()) :: {:ok, t()} | {:error, term()}
  def modify_me(guild_id, opts \\ []) do
    EDA.API.Member.modify_me(guild_id, opts) |> parse_response()
  end

  @doc """
  Kicks a member from a guild.

  ## Options

  - `:reason` - Audit log reason
  """
  @spec kick(String.t() | integer(), t() | String.t() | integer(), keyword()) ::
          :ok | {:error, term()}
  def kick(guild_id, member, opts \\ [])

  def kick(guild_id, %__MODULE__{user: %{id: uid}}, opts), do: kick(guild_id, uid, opts)

  def kick(guild_id, user_id, opts) when is_binary(user_id) or is_integer(user_id) do
    EDA.API.Member.remove(guild_id, user_id, opts)
  end

  @doc """
  Adds a role to a guild member.

  ## Options

  - `:reason` - Audit log reason
  """
  @spec add_role(
          String.t() | integer(),
          t() | String.t() | integer(),
          String.t() | integer(),
          keyword()
        ) :: :ok | {:error, term()}
  def add_role(guild_id, member, role_id, opts \\ [])

  def add_role(guild_id, %__MODULE__{user: %{id: uid}}, role_id, opts),
    do: add_role(guild_id, uid, role_id, opts)

  def add_role(guild_id, user_id, role_id, opts)
      when is_binary(user_id) or is_integer(user_id) do
    EDA.API.Member.add_role(guild_id, user_id, role_id, opts)
  end

  @doc """
  Removes a role from a guild member.

  ## Options

  - `:reason` - Audit log reason
  """
  @spec remove_role(
          String.t() | integer(),
          t() | String.t() | integer(),
          String.t() | integer(),
          keyword()
        ) :: :ok | {:error, term()}
  def remove_role(guild_id, member, role_id, opts \\ [])

  def remove_role(guild_id, %__MODULE__{user: %{id: uid}}, role_id, opts),
    do: remove_role(guild_id, uid, role_id, opts)

  def remove_role(guild_id, user_id, role_id, opts)
      when is_binary(user_id) or is_integer(user_id) do
    EDA.API.Member.remove_role(guild_id, user_id, role_id, opts)
  end

  @doc """
  Applies a changeset to a member. No-op if the changeset has no changes.

  Requires `guild_id` since members are guild-scoped.

  ## Options

  - `:reason` - Audit log reason
  """
  @spec apply_changeset(String.t() | integer(), Changeset.t(), keyword()) ::
          {:ok, t()} | {:error, term()}
  def apply_changeset(guild_id, changeset, opts \\ [])

  def apply_changeset(guild_id, %Changeset{module: __MODULE__, entity: entity} = cs, opts) do
    if Changeset.changed?(cs) do
      modify(guild_id, entity, Changeset.changes(cs), opts)
    else
      {:ok, entity}
    end
  end
end
