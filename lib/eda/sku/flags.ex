defmodule EDA.SKU.Flags do
  @moduledoc """
  A SKU's `flags`: `:available` once it can be bought, and whether a subscription is bought for
  a guild (`:guild_subscription`) or for a user (`:user_subscription`).

      iex> EDA.SKU.Flags.to_list(4 + 256)
      [:available, :user_subscription]

  The calls are those of every flags module in EDA: `to_list/1`, `has?/2`, `to_bit/1`,
  `to_bitset/1`, `from_bit/1`. Bits Discord does not document are skipped.
  """

  import Bitwise

  use EDA.Flags,
    flags: %{
      available: 1 <<< 2,
      guild_subscription: 1 <<< 7,
      user_subscription: 1 <<< 8
    }
end
