defmodule EDA.Activity.Flags do
  @moduledoc """
  What an activity supports, as the bits of its `flags`: joining, spectating, syncing (music
  played along), being embedded in Discord…

  `EDA.Activity.flag?/2` reads it straight off an activity.

      iex> EDA.Activity.Flags.to_list(1 <<< 1 ||| 1 <<< 4)
      [:join, :sync]

  The calls are those of every flags module in EDA: `to_list/1`, `has?/2`, `to_bit/1`,
  `to_bitset/1`, `from_bit/1`. Bits Discord does not document are skipped.
  """

  import Bitwise

  use EDA.Flags,
    flags: %{
      instance: 1 <<< 0,
      join: 1 <<< 1,
      spectate: 1 <<< 2,
      join_request: 1 <<< 3,
      sync: 1 <<< 4,
      play: 1 <<< 5,
      party_privacy_friends: 1 <<< 6,
      party_privacy_voice_channel: 1 <<< 7,
      embedded: 1 <<< 8
    }
end
