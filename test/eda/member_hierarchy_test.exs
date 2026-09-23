defmodule EDA.MemberHierarchyTest do
  @moduledoc """
  How a member shows in a guild (name, roles, colour) and what the bot may do to them, from the
  cached guild, roles and members.
  """

  # NOT async — the caches and the bot user are global.
  use ExUnit.Case

  alias EDA.{Member, Permission, Role}

  doctest EDA.Member, only: [display_name: 1]
  doctest EDA.Role, only: [compare: 2, hex_color: 1]

  @guild "7713000000000000000"
  @owner "7713000000000000001"
  @bot "7713000000000000002"
  @user "7713000000000000003"
  @admin "7713000000000000004"
  @boss "7713000000000000005"

  setup do
    previous = :persistent_term.get(:eda_current_user_raw, nil)
    EDA.Cache.put_me(%{"id" => @bot, "username" => "bot"})

    on_exit(fn ->
      if previous,
        do: EDA.Cache.put_me(previous),
        else:
          :persistent_term.erase(:eda_current_user) &&
            :persistent_term.erase(:eda_current_user_raw)
    end)

    EDA.Cache.Guild.create(%{"id" => @guild, "name" => "H", "owner_id" => @owner})

    roles = [
      {@guild, 0, 0, [:view_channel]},
      {"7713000000000000011", 2, 0x2ECC71, []},
      {"7713000000000000012", 1, 0, [:administrator]},
      {"7713000000000000013", 5, 0,
       [:kick_members, :ban_members, :moderate_members, :manage_roles]},
      {"7713000000000000014", 9, 0xE91E63, []}
    ]

    for {id, position, color, perms} <- roles do
      EDA.Cache.Role.create(@guild, %{
        "id" => id,
        "position" => position,
        "color" => color,
        "permissions" => to_string(Permission.to_bitset(perms))
      })
    end

    for {user, role_ids} <- [
          {@owner, []},
          {@bot, ["7713000000000000013"]},
          {@user, ["7713000000000000011"]},
          {@admin, ["7713000000000000012"]},
          {@boss, ["7713000000000000014", "7713000000000000011"]}
        ] do
      EDA.Cache.Member.create(@guild, %{"user" => %{"id" => user}, "roles" => role_ids})
    end

    :ok
  end

  defp member(user), do: %{Member.from_raw(EDA.Cache.get_member(@guild, user)) | guild_id: @guild}

  test "roles come highest first, and the name's colour is the highest coloured one" do
    boss = member(@boss)

    assert [%Role{id: "7713000000000000014"}, %Role{id: "7713000000000000011"}] =
             Member.roles(boss, @guild)

    assert Member.color(boss, @guild) == 0xE91E63
    assert Member.color(member(@bot), @guild) == nil
  end

  test "the owner acts on anyone, and no one acts on the owner" do
    assert Member.owner?(member(@owner), @guild)
    assert Member.can_interact?(member(@owner), member(@boss), @guild)
    refute Member.can_interact?(member(@boss), member(@owner), @guild)
  end

  test "otherwise the highest role decides" do
    assert Member.can_interact?(member(@boss), member(@bot), @guild)
    refute Member.can_interact?(member(@bot), member(@boss), @guild)
    refute Member.can_interact?(member(@user), member(@user), @guild)
  end

  test "what the bot may do to a member: hierarchy and its permissions" do
    assert Member.kickable?(member(@user), @guild)
    assert Member.bannable?(member(@user), @guild)
    assert Member.moderatable?(member(@user), @guild)

    # An administrator below the bot can be kicked but never timed out.
    assert Member.kickable?(member(@admin), @guild)
    refute Member.moderatable?(member(@admin), @guild)

    refute Member.manageable?(member(@boss), @guild)
    refute Member.manageable?(member(@owner), @guild)
    refute Member.manageable?(member(@bot), @guild)
  end

  test "the bot edits the roles below its own, not those above or managed" do
    below = %{Role.from_raw(EDA.Cache.Role.get(@guild, "7713000000000000011")) | guild_id: @guild}
    above = %{Role.from_raw(EDA.Cache.Role.get(@guild, "7713000000000000014")) | guild_id: @guild}

    assert Role.editable?(below)
    refute Role.editable?(above)
    refute Role.editable?(%{below | managed: true})
    assert Role.hex_color(above) == "#e91e63"
  end
end
