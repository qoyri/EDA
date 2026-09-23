defmodule EDA.Message.Flags do
  @moduledoc """
  What a message is, as the bits of its `flags`: crossposted, ephemeral, a voice message, a
  forward, built with components v2…

  `EDA.Message.flags/1` and `EDA.Message.flag?/2` read it straight off a message.

      iex> EDA.Message.Flags.to_list(1 <<< 6 ||| 1 <<< 13)
      [:ephemeral, :is_voice_message]

  When sending, only `:suppress_embeds`, `:suppress_notifications`, `:is_voice_message` and
  `:is_components_v2` can be set, and `:ephemeral` on an interaction response; once a message is
  sent with `:is_components_v2`, the flag cannot be removed.

  The calls are those of every flags module in EDA: `to_list/1`, `has?/2`, `to_bit/1`,
  `to_bitset/1`, `from_bit/1`. Bits Discord does not document are skipped.
  """

  import Bitwise

  use EDA.Flags,
    flags: %{
      crossposted: 1 <<< 0,
      is_crosspost: 1 <<< 1,
      suppress_embeds: 1 <<< 2,
      source_message_deleted: 1 <<< 3,
      urgent: 1 <<< 4,
      has_thread: 1 <<< 5,
      ephemeral: 1 <<< 6,
      loading: 1 <<< 7,
      failed_to_mention_some_roles_in_thread: 1 <<< 8,
      suppress_notifications: 1 <<< 12,
      is_voice_message: 1 <<< 13,
      has_snapshot: 1 <<< 14,
      is_components_v2: 1 <<< 15
    }
end
