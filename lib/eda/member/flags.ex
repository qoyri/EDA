defmodule EDA.Member.Flags do
  @moduledoc """
  What a member has done in a guild, as the bits of their `flags`.

  Discord sends an integer; this turns it into atoms and back, like `EDA.User.Flags` does for
  profile badges. `EDA.Member.flags/1` reads it straight off a member.

  Only `:bypasses_verification` can be written back, through `EDA.Member.modify/4`; Discord
  refuses to set any of the others.

      iex> EDA.Member.Flags.to_list(1 ||| 1 <<< 1)
      [:did_rejoin, :completed_onboarding]

  `:automod_quarantined_username` and `:automod_quarantined_guild_tag` are how automod says it
  is hiding a member's name or server tag, which is otherwise invisible to a bot.

  The other calls, as on every flags module:

      iex> EDA.Member.Flags.to_bit(:bypasses_verification)
      4

      iex> EDA.Member.Flags.to_bitset([:did_rejoin, :is_guest])
      17

      iex> EDA.Member.Flags.has?(nil, :is_guest)
      false
  """

  import Bitwise

  use EDA.Flags,
    flags: %{
      did_rejoin: 1 <<< 0,
      completed_onboarding: 1 <<< 1,
      bypasses_verification: 1 <<< 2,
      started_onboarding: 1 <<< 3,
      is_guest: 1 <<< 4,
      started_home_actions: 1 <<< 5,
      completed_home_actions: 1 <<< 6,
      automod_quarantined_username: 1 <<< 7,
      dm_settings_upsell_acknowledged: 1 <<< 9,
      automod_quarantined_guild_tag: 1 <<< 10
    }
end
