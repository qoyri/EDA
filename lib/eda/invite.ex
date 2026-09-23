defmodule EDA.Invite do
  @moduledoc """
  Represents a Discord invite.

  The same struct covers both shapes Discord sends. The REST invite object nests `guild` and
  `channel` objects; the `INVITE_CREATE` gateway event sends flat `guild_id` and
  `channel_id` instead. `guild_id` and `channel_id` are filled in from the nested objects
  when Discord did not send them, so they can be read either way.
  """
  use EDA.Event.Access

  import Bitwise

  defstruct [
    :code,
    :type,
    :guild,
    :guild_id,
    :channel,
    :channel_id,
    :inviter,
    :target_user,
    :target_type,
    :target_application,
    :roles,
    :flags,
    :expires_at,
    :created_at,
    :approximate_member_count,
    :approximate_presence_count,
    :guild_scheduled_event,
    :max_age,
    :max_uses,
    :uses,
    :temporary
  ]

  @type t :: %__MODULE__{
          code: String.t() | nil,
          type: integer() | nil,
          guild: map() | nil,
          guild_id: String.t() | nil,
          channel: map() | nil,
          channel_id: String.t() | nil,
          inviter: EDA.User.t() | nil,
          target_user: EDA.User.t() | nil,
          target_type: integer() | nil,
          target_application: map() | nil,
          roles: [EDA.Role.t()] | nil,
          flags: integer() | nil,
          expires_at: String.t() | nil,
          created_at: String.t() | nil,
          approximate_member_count: integer() | nil,
          approximate_presence_count: integer() | nil,
          guild_scheduled_event: map() | nil,
          max_age: integer() | nil,
          max_uses: integer() | nil,
          uses: integer() | nil,
          temporary: boolean() | nil
        }

  @spec from_raw(map()) :: t()
  def from_raw(raw) when is_map(raw) do
    guild = raw["guild"]
    channel = raw["channel"]

    %__MODULE__{
      code: raw["code"],
      type: raw["type"],
      guild: guild,
      guild_id: raw["guild_id"] || nested_id(guild),
      channel: channel,
      channel_id: raw["channel_id"] || nested_id(channel),
      inviter: parse_user(raw["inviter"]),
      target_user: parse_user(raw["target_user"]),
      target_type: raw["target_type"],
      target_application: raw["target_application"],
      roles: parse_roles(raw["roles"]),
      flags: raw["flags"],
      expires_at: raw["expires_at"],
      created_at: raw["created_at"],
      approximate_member_count: raw["approximate_member_count"],
      approximate_presence_count: raw["approximate_presence_count"],
      guild_scheduled_event: raw["guild_scheduled_event"],
      max_age: raw["max_age"],
      max_uses: raw["max_uses"],
      uses: raw["uses"],
      temporary: raw["temporary"]
    }
  end

  defp nested_id(%{"id" => id}), do: id
  defp nested_id(_other), do: nil

  defp parse_user(nil), do: nil
  defp parse_user(raw) when is_map(raw), do: EDA.User.from_raw(raw)

  defp parse_roles(nil), do: nil
  defp parse_roles(list) when is_list(list), do: Enum.map(list, &EDA.Role.from_raw/1)

  # ── Types and flags ──

  @invite_types %{0 => :guild, 1 => :group_dm, 2 => :friend}
  @target_types %{1 => :stream, 2 => :embedded_application}

  @flag_guest_invite 1 <<< 0
  @flag_has_target_users 1 <<< 4

  @doc "This invite is a guest invite (`1 <<< 0`)."
  @spec flag_guest_invite() :: integer()
  def flag_guest_invite, do: @flag_guest_invite

  @doc """
  This invite is restricted to a list of target users (`1 <<< 4`).

  **Discord does not document this bit**, and it does not always set it. Observed on
  2026-09-19 and again on 2026-09-23: an invite whose list was uploaded as a CSV returns
  `flags: 16`, one created with a JSON list of ids carries **no `flags` key at all** although
  it does restrict who may accept it, and so does an invite with no list. Treat it as a hint
  rather than a contract — `EDA.API.Invite.target_users/1` is the authoritative answer.
  """
  @spec flag_has_target_users() :: integer()
  def flag_has_target_users, do: @flag_has_target_users

  @doc """
  Names the invite's kind.

  ## Examples

      iex> EDA.Invite.type(%EDA.Invite{type: 0})
      :guild

      iex> EDA.Invite.type(%EDA.Invite{type: nil})
      :guild
  """
  @spec type(t() | map() | integer() | nil) :: :guild | :group_dm | :friend | :unknown
  def type(%__MODULE__{type: type}), do: type(type)
  def type(%{"type" => type}), do: type(type)
  # Discord omits `type` on the gateway event, where it is always a guild invite.
  def type(nil), do: :guild
  def type(value) when is_integer(value), do: Map.get(@invite_types, value, :unknown)

  @doc """
  Names what a voice channel invite points at, or `nil` for an ordinary invite.

  ## Examples

      iex> EDA.Invite.target_type(%EDA.Invite{target_type: 1})
      :stream

      iex> EDA.Invite.target_type(%EDA.Invite{target_type: nil})
      nil
  """
  @spec target_type(t() | map() | integer() | nil) ::
          :stream | :embedded_application | :unknown | nil
  def target_type(%__MODULE__{target_type: value}), do: target_type(value)
  def target_type(%{"target_type" => value}), do: target_type(value)
  def target_type(nil), do: nil
  def target_type(value) when is_integer(value), do: Map.get(@target_types, value, :unknown)

  @doc """
  Returns `true` if this is a guest invite.

  Accepts a `t:t/0`, a raw invite map, a bitfield, or `nil`.

  ## Examples

      iex> EDA.Invite.guest_invite?(%EDA.Invite{flags: 1})
      true

      iex> EDA.Invite.guest_invite?(nil)
      false
  """
  @spec guest_invite?(t() | map() | integer() | nil) :: boolean()
  def guest_invite?(%__MODULE__{flags: flags}), do: guest_invite?(flags)
  def guest_invite?(%{"flags" => flags}), do: guest_invite?(flags)

  def guest_invite?(bitfield) when is_integer(bitfield),
    do: (bitfield &&& @flag_guest_invite) == @flag_guest_invite

  def guest_invite?(_invite), do: false

  @doc """
  Returns `true` if this invite is restricted to a list of target users.

  Reads the undocumented bit described on `flag_has_target_users/0`, so a `false` here is
  weaker than a `{:ok, []}` from `EDA.API.Invite.target_users/1` — an invite restricted
  through a JSON list of ids answers `false` here and still has target users.

  ## Examples

      iex> EDA.Invite.has_target_users?(%EDA.Invite{flags: 16})
      true

      iex> EDA.Invite.has_target_users?(%EDA.Invite{flags: nil})
      false
  """
  @spec has_target_users?(t() | map() | integer() | nil) :: boolean()
  def has_target_users?(%__MODULE__{flags: flags}), do: has_target_users?(flags)
  def has_target_users?(%{"flags" => flags}), do: has_target_users?(flags)

  def has_target_users?(bitfield) when is_integer(bitfield),
    do: (bitfield &&& @flag_has_target_users) == @flag_has_target_users

  def has_target_users?(_invite), do: false

  @doc """
  Returns `true` if the invite never expires.

  Discord expresses that as `max_age: 0`, and as a null `expires_at` on the REST object.

  ## Examples

      iex> EDA.Invite.permanent?(%EDA.Invite{max_age: 0})
      true

      iex> EDA.Invite.permanent?(%EDA.Invite{max_age: 3600})
      false
  """
  @spec permanent?(t() | map()) :: boolean()
  def permanent?(%__MODULE__{max_age: 0}), do: true
  def permanent?(%__MODULE__{max_age: age}) when is_integer(age), do: false
  def permanent?(%__MODULE__{expires_at: nil, max_age: nil}), do: true
  def permanent?(%__MODULE__{}), do: false
  def permanent?(raw) when is_map(raw), do: raw |> from_raw() |> permanent?()

  @doc """
  The invite's URL.

  ## Examples

      iex> EDA.Invite.url(%EDA.Invite{code: "abc123"})
      "https://discord.gg/abc123"

      iex> EDA.Invite.url("abc123")
      "https://discord.gg/abc123"
  """
  @spec url(t() | map() | String.t()) :: String.t() | nil
  def url(%__MODULE__{code: nil}), do: nil
  def url(%__MODULE__{code: code}), do: url(code)
  def url(%{"code" => code}), do: url(code)
  def url(code) when is_binary(code), do: "https://discord.gg/" <> code

  # ── Entity Manager ──

  use EDA.Entity

  @doc """
  Fetches an invite by code. No cache — invites are not cached.

  Named `fetch_invite/2` rather than `fetch/2` because `Access.fetch/2` owns that arity.

  ## Options

    * `:with_counts` - include the approximate member and presence counts
    * `:guild_scheduled_event_id` - include that event

  ## Examples

      EDA.Invite.fetch_invite("abc123", with_counts: true)
  """
  @spec fetch_invite(String.t(), keyword()) :: {:ok, t()} | {:error, term()}
  def fetch_invite(invite_code, opts \\ []) do
    EDA.API.Invite.get(invite_code, opts) |> parse_response()
  end

  @doc """
  Creates an invite for a channel. Returns a `t:t/0`.

  Takes the same options as `EDA.API.Invite.create/2`, including `:role_ids` and
  `:target_users`.
  """
  @spec create(String.t() | integer(), keyword() | map()) :: {:ok, t()} | {:error, term()}
  def create(channel_id, opts \\ []) do
    EDA.API.Invite.create(channel_id, opts) |> parse_response()
  end

  @doc """
  Deletes an invite.

  ## Options

    * `:reason` - audit log reason
  """
  @spec delete(t() | String.t(), keyword()) :: {:ok, t()} | {:error, term()}
  def delete(invite, opts \\ [])

  def delete(%__MODULE__{code: code}, opts), do: delete(code, opts)

  def delete(invite_code, opts) when is_binary(invite_code) do
    EDA.API.Invite.delete(invite_code, opts) |> parse_response()
  end

  @doc """
  Lists the user ids allowed to accept this invite.

  See `EDA.API.Invite.target_users/1`.
  """
  @spec target_users(t() | String.t()) :: {:ok, [String.t()]} | {:error, term()}
  def target_users(%__MODULE__{code: code}), do: target_users(code)

  def target_users(invite_code) when is_binary(invite_code),
    do: EDA.API.Invite.target_users(invite_code)

  @doc """
  Replaces the user ids allowed to accept this invite.

  Applied asynchronously — see `EDA.API.Invite.target_users_job_status/1`.
  """
  @spec set_target_users(t() | String.t(), [String.t() | integer()] | binary()) ::
          {:ok, map()} | {:error, term()}
  def set_target_users(%__MODULE__{code: code}, users), do: set_target_users(code, users)

  def set_target_users(invite_code, users) when is_binary(invite_code),
    do: EDA.API.Invite.update_target_users(invite_code, users)

  @typedoc "A user to add to or remove from a target list: a struct, a raw map, or an id."
  @type user :: EDA.User.t() | EDA.Member.t() | map() | String.t() | integer()

  @doc """
  Lets one more user accept this invite, leaving the rest of the list alone.

  Applies at once, unlike `set_target_users/2`. See `EDA.API.Invite.add_target_user/2`.
  """
  @spec add_target_user(t() | String.t(), user()) :: :ok | {:error, term()}
  def add_target_user(%__MODULE__{code: code}, user), do: add_target_user(code, user)

  def add_target_user(invite_code, user) when is_binary(invite_code),
    do: EDA.API.Invite.add_target_user(invite_code, user_id(user))

  @doc """
  Stops one user from accepting this invite, leaving the rest of the list alone.

  See `EDA.API.Invite.remove_target_user/2`.
  """
  @spec remove_target_user(t() | String.t(), user()) :: :ok | {:error, term()}
  def remove_target_user(%__MODULE__{code: code}, user), do: remove_target_user(code, user)

  def remove_target_user(invite_code, user) when is_binary(invite_code),
    do: EDA.API.Invite.remove_target_user(invite_code, user_id(user))

  @doc """
  Adds up to 1000 users to this invite's list at once, leaving the rest of it alone.

  See `EDA.API.Invite.add_target_users/2`.
  """
  @spec add_target_users(t() | String.t(), [user()]) :: :ok | {:error, term()}
  def add_target_users(%__MODULE__{code: code}, users), do: add_target_users(code, users)

  def add_target_users(invite_code, users) when is_binary(invite_code) and is_list(users),
    do: EDA.API.Invite.add_target_users(invite_code, Enum.map(users, &user_id/1))

  @doc """
  Removes up to 1000 users from this invite's list at once, leaving the rest of it alone.

  See `EDA.API.Invite.remove_target_users/2`.
  """
  @spec remove_target_users(t() | String.t(), [user()]) :: :ok | {:error, term()}
  def remove_target_users(%__MODULE__{code: code}, users), do: remove_target_users(code, users)

  def remove_target_users(invite_code, users) when is_binary(invite_code) and is_list(users),
    do: EDA.API.Invite.remove_target_users(invite_code, Enum.map(users, &user_id/1))

  # Takes a user the way the caller has them: a struct, a raw map, or an id.
  defp user_id(%EDA.User{id: id}), do: id
  defp user_id(%EDA.Member{user: %{id: id}}), do: id
  defp user_id(%{"id" => id}), do: id
  defp user_id(id) when is_binary(id) or is_integer(id), do: id
end
