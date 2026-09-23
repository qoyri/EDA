defmodule EDA.Guild.SystemChannelFlags do
  @moduledoc """
  Which notices a guild's system channel leaves out, as the bits of `system_channel_flags`.

  `EDA.Guild.system_channel_flag?/2` reads it straight off a guild. Each flag *suppresses*
  something: `:suppress_join_notifications` set means join messages are not posted.

      iex> EDA.Guild.SystemChannelFlags.to_list(1 <<< 0 ||| 1 <<< 1)
      [:suppress_join_notifications, :suppress_premium_subscriptions]

  The calls are those of every flags module in EDA: `to_list/1`, `has?/2`, `to_bit/1`,
  `to_bitset/1`, `from_bit/1`. Bits Discord does not document are skipped.
  """

  import Bitwise

  use EDA.Flags,
    flags: %{
      suppress_join_notifications: 1 <<< 0,
      suppress_premium_subscriptions: 1 <<< 1,
      suppress_guild_reminder_notifications: 1 <<< 2,
      suppress_join_notification_replies: 1 <<< 3,
      suppress_role_subscription_purchase_notifications: 1 <<< 4,
      suppress_role_subscription_purchase_notification_replies: 1 <<< 5
    }
end
