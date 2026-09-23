defmodule EDA.Cache.PatchTest do
  @moduledoc """
  The caches hold structs and apply Discord's partial updates to them: a key sent replaces the
  field, `null` clears it, a key left out keeps it.
  """

  # NOT async — the caches are shared.
  use ExUnit.Case

  doctest EDA.Entity, only: [patch: 2]

  @guild "7717000000000000000"

  test "a member update replaces what it sends and keeps the rest" do
    EDA.Cache.Member.create(@guild, %{
      "user" => %{"id" => "7717000000000000001", "username" => "ann"},
      "nick" => "Annie",
      "roles" => ["1"],
      "joined_at" => "2024-01-01T00:00:00+00:00"
    })

    EDA.Cache.Member.update(@guild, "7717000000000000001", %{"roles" => ["1", "2"], "nick" => nil})

    member = EDA.Cache.get_member(@guild, "7717000000000000001")
    assert %EDA.Member{roles: ["1", "2"], nick: nil, guild_id: @guild} = member
    assert member.joined_at == ~U[2024-01-01 00:00:00Z]
    assert member.user.username == "ann"
  end

  test "a channel update reaches its voice part, and keeps the fields it leaves out" do
    EDA.Cache.Channel.create(%{
      "id" => "7717000000000000010",
      "guild_id" => @guild,
      "type" => 2,
      "name" => "Lounge",
      "bitrate" => 64_000,
      "user_limit" => 5
    })

    EDA.Cache.Channel.update("7717000000000000010", %{"status" => "movie night"})

    channel = EDA.Cache.get_channel("7717000000000000010")
    assert %EDA.Channel{type: :guild_voice, name: "Lounge"} = channel

    assert %EDA.Channel.Voice{bitrate: 64_000, user_limit: 5, status: "movie night"} =
             channel.voice
  end

  test "a guild update keeps the owner it does not resend" do
    EDA.Cache.Guild.create(%{"id" => @guild, "name" => "Old", "owner_id" => "9"})
    EDA.Cache.Guild.update(@guild, %{"name" => "New"})

    assert %EDA.Guild{name: "New", owner_id: "9"} = EDA.Cache.get_guild(@guild)
  end

  test "the user cache does not keep the member Discord attaches to a mention" do
    EDA.Cache.User.create(%{"id" => "7717000000000000020", "member" => %{"nick" => "x"}})
    assert %EDA.User{member: nil} = EDA.Cache.get_user("7717000000000000020")
  end
end
