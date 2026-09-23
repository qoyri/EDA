defmodule EDA.CachedStructSizeTest do
  @moduledoc """
  The structs the cache holds by the thousand stay within 31 fields.

  A map keeps a compact form up to 32 keys — 31 fields plus `__struct__`. Past that it becomes a
  tree: measured at 296 bytes for a 31-field struct against 1040 for a 33-field one, and slower to
  read. That is negligible for a message, which is not cached, and heavy for a member or a
  channel, of which a large bot holds hundreds of thousands. Past the limit, group what only some
  of them carry into a nested struct, as `EDA.Channel` does with `thread`, `forum`, `voice` and
  `dm`.
  """

  use ExUnit.Case, async: true

  @held_in_bulk [
    EDA.Channel,
    EDA.Member,
    EDA.User,
    EDA.Role,
    EDA.VoiceState,
    EDA.Emoji,
    EDA.Channel.Thread,
    EDA.Channel.ThreadMember
  ]

  for mod <- @held_in_bulk do
    test "#{inspect(mod)} has at most 31 fields" do
      fields = unquote(mod).__struct__() |> Map.delete(:__struct__) |> map_size()
      assert fields <= 31, "#{inspect(unquote(mod))} has #{fields} fields"
    end
  end
end
