defmodule EDA.Role.Flags do
  @moduledoc """
  A role's `flags`. Discord documents one: `:in_prompt`, set on a role members can pick in an
  onboarding prompt.

      iex> EDA.Role.Flags.to_list(1)
      [:in_prompt]

  The calls are those of every flags module in EDA: `to_list/1`, `has?/2`, `to_bit/1`,
  `to_bitset/1`, `from_bit/1`. Bits Discord does not document are skipped.
  """

  import Bitwise

  use EDA.Flags,
    flags: %{
      in_prompt: 1 <<< 0
    }
end
