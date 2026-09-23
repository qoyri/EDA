defmodule EDA.Event.GuildMemberAdd do
  @moduledoc """
  Dispatched when a user joins a guild.

  Carries the fields of the member object Discord sends with it, `member/1` builds an
  `EDA.Member` from them — for `EDA.Member.flags/1`, `EDA.Permission.for_member/2` and the rest.
  """
  use EDA.Event.Access

  defstruct [
    :guild_id,
    :user,
    :nick,
    :roles,
    :joined_at,
    :deaf,
    :mute,
    :pending,
    :avatar,
    :banner,
    :premium_since,
    :flags,
    :communication_disabled_until
  ]

  @type t :: %__MODULE__{
          guild_id: String.t() | nil,
          user: EDA.User.t() | nil,
          nick: String.t() | nil,
          roles: [String.t()] | nil,
          joined_at: String.t() | nil,
          deaf: boolean() | nil,
          mute: boolean() | nil,
          pending: boolean() | nil,
          avatar: String.t() | nil,
          banner: String.t() | nil,
          premium_since: String.t() | nil,
          flags: integer() | nil,
          communication_disabled_until: String.t() | nil
        }

  @doc "Converts a raw Discord payload into this event struct."
  @spec from_raw(map()) :: t()
  def from_raw(raw) when is_map(raw) do
    %__MODULE__{
      guild_id: raw["guild_id"],
      user: parse_user(raw["user"]),
      nick: raw["nick"],
      roles: raw["roles"],
      joined_at: raw["joined_at"],
      deaf: raw["deaf"],
      mute: raw["mute"],
      pending: raw["pending"],
      avatar: raw["avatar"],
      banner: raw["banner"],
      premium_since: raw["premium_since"],
      flags: raw["flags"],
      communication_disabled_until: raw["communication_disabled_until"]
    }
  end

  @doc """
  The member that joined, as an `EDA.Member`.

      EDA.Event.GuildMemberAdd.member(event) |> EDA.Member.flags()
  """
  @spec member(t()) :: EDA.Member.t()
  def member(%__MODULE__{} = event) do
    %EDA.Member{
      user: event.user,
      nick: event.nick,
      avatar: event.avatar,
      banner: event.banner,
      roles: event.roles,
      joined_at: event.joined_at,
      premium_since: event.premium_since,
      deaf: event.deaf,
      mute: event.mute,
      pending: event.pending,
      flags: event.flags,
      communication_disabled_until: event.communication_disabled_until
    }
  end

  defp parse_user(nil), do: nil
  defp parse_user(raw) when is_map(raw), do: EDA.User.from_raw(raw)
end
