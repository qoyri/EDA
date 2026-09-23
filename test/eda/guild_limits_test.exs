defmodule EDA.GuildLimitsTest do
  @moduledoc """
  A guild's features and the limits its boost level and features set, and its roles in order.
  """

  # NOT async — sorted_roles/1 and everyone_role/1 read the shared role cache.
  use ExUnit.Case

  alias EDA.Guild

  doctest EDA.Guild, only: [feature?: 2, max_file_size: 1]

  test "the limits follow the boost level, and the features that raise them" do
    base = %Guild{premium_tier: :none, features: []}

    assert {Guild.max_file_size(base), Guild.max_bitrate(base), Guild.max_emojis(base),
            Guild.max_stickers(base)} == {10_485_760, 96_000, 50, 5}

    tier3 = %Guild{premium_tier: :tier_3, features: []}

    assert {Guild.max_bitrate(tier3), Guild.max_emojis(tier3), Guild.max_stickers(tier3)} ==
             {384_000, 250, 60}

    featured = %Guild{
      premium_tier: :tier_1,
      features: ["VIP_REGIONS", "MORE_EMOJI", "MORE_STICKERS"]
    }

    assert {Guild.max_bitrate(featured), Guild.max_emojis(featured), Guild.max_stickers(featured)} ==
             {384_000, 200, 60}
  end

  test "@everyone and the roles in order, from the guild or the cache" do
    guild_id = "7715000000000000000"
    EDA.Cache.Role.create(guild_id, %{"id" => guild_id, "name" => "@everyone", "position" => 0})

    EDA.Cache.Role.create(guild_id, %{
      "id" => "7715000000000000002",
      "name" => "b",
      "position" => 1
    })

    EDA.Cache.Role.create(guild_id, %{
      "id" => "7715000000000000001",
      "name" => "a",
      "position" => 1
    })

    assert %EDA.Role{name: "@everyone", guild_id: ^guild_id} = Guild.everyone_role(guild_id)

    # At the same position, the older role (lower id) is above.
    assert ["a", "b", "@everyone"] = guild_id |> Guild.sorted_roles() |> Enum.map(& &1.name)

    guild = %Guild{
      id: "1",
      roles: [%EDA.Role{id: "1", position: 0}, %EDA.Role{id: "2", position: 3}]
    }

    assert [%EDA.Role{id: "2"}, %EDA.Role{id: "1"}] = Guild.sorted_roles(guild)
    assert %EDA.Role{id: "1"} = Guild.everyone_role(guild)
  end
end
