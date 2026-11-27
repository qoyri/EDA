defmodule EDA.Embed.Flags do
  @moduledoc """
  An embed's `flags`: what Discord's content scanning found in its media
  (`:contains_explicit_content`, `:contains_gore_content`, `:contains_self_harm_content`), and
  `:is_content_inventory_entry` on the fallback embed of a reply to an activity card.

      iex> EDA.Embed.Flags.to_list(0b1010000)
      [:contains_explicit_content, :contains_gore_content]

  `EDA.Embed.content_flags/1` gives the scanning result alone. The calls are those of every
  flags module in EDA: `to_list/1`, `has?/2`, `to_bit/1`, `to_bitset/1`, `from_bit/1`. Bits
  Discord does not document are skipped.
  """

  import Bitwise

  use EDA.Flags,
    flags: %{
      contains_explicit_content: 1 <<< 4,
      is_content_inventory_entry: 1 <<< 5,
      contains_gore_content: 1 <<< 6,
      contains_self_harm_content: 1 <<< 7
    }
end
