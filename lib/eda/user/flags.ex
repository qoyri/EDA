defmodule EDA.User.Flags do
  @moduledoc """
  The badges on a user's profile, as the bits of `public_flags`.

  Discord sends an integer; this turns it into atoms and back, like `EDA.Permission` does for
  permissions. `EDA.User.badges/1` reads it straight off a user.

      iex> EDA.User.Flags.to_list(1 <<< 0 ||| 1 <<< 22)
      [:staff, :active_developer]

  `:active_developer` is not in Discord's table of user flags, but the badge exists and the bit
  is stable; a bot that ignores it misreads a common profile. Bits Discord does not document at
  all are skipped by `to_list/1` rather than guessed at.

  Flags with no badge of their own are here because Discord documents them: `:team_pseudo_user`
  marks the pseudo-user of a team, `:verified_bot` and `:bot_http_interactions` describe a bot,
  and `:hypesquad` is the events member flag, distinct from the three house flags.

  The other calls, as on every flags module:

      iex> EDA.User.Flags.to_bit(:active_developer)
      4194304

      iex> EDA.User.Flags.from_bit(1 <<< 30)
      :error

      iex> EDA.User.Flags.has?(64, :hypesquad_online_house_1)
      true

      iex> EDA.User.Flags.to_list(nil)
      []
  """

  import Bitwise

  use EDA.Flags,
    flags: %{
      staff: 1 <<< 0,
      partner: 1 <<< 1,
      hypesquad: 1 <<< 2,
      bug_hunter_level_1: 1 <<< 3,
      hypesquad_online_house_1: 1 <<< 6,
      hypesquad_online_house_2: 1 <<< 7,
      hypesquad_online_house_3: 1 <<< 8,
      premium_early_supporter: 1 <<< 9,
      team_pseudo_user: 1 <<< 10,
      bug_hunter_level_2: 1 <<< 14,
      verified_bot: 1 <<< 16,
      verified_developer: 1 <<< 17,
      certified_moderator: 1 <<< 18,
      bot_http_interactions: 1 <<< 19,
      active_developer: 1 <<< 22
    }

  @doc """
  The three HypeSquad houses, in Discord's order: bravery, brilliance, balance.

      iex> EDA.User.Flags.houses()
      [:hypesquad_online_house_1, :hypesquad_online_house_2, :hypesquad_online_house_3]
  """
  @spec houses() :: [flag()]
  def houses,
    do: [:hypesquad_online_house_1, :hypesquad_online_house_2, :hypesquad_online_house_3]
end
