defmodule EDA.InviteTest do
  use ExUnit.Case, async: true

  alias EDA.Invite

  doctest EDA.Invite

  describe "the two shapes Discord sends" do
    test "the REST object nests guild and channel, and the ids are derived from them" do
      invite =
        Invite.from_raw(%{
          "code" => "abc123",
          "type" => 0,
          "guild" => %{"id" => "g1", "name" => "A guild"},
          "channel" => %{"id" => "ch1", "name" => "general"},
          "expires_at" => "2026-09-26T12:00:00Z"
        })

      assert invite.guild_id == "g1"
      assert invite.channel_id == "ch1"
      assert invite.guild["name"] == "A guild"
      assert invite.channel["name"] == "general"
      assert invite.expires_at == "2026-09-26T12:00:00Z"
    end

    test "the gateway event sends flat ids and no nested objects" do
      invite = Invite.from_raw(%{"code" => "abc", "guild_id" => "g1", "channel_id" => "ch1"})

      assert invite.guild_id == "g1"
      assert invite.channel_id == "ch1"
      assert invite.guild == nil
      assert invite.channel == nil
    end

    test "an explicit id wins over the nested object, rather than being overwritten" do
      invite =
        Invite.from_raw(%{"code" => "a", "guild_id" => "flat", "guild" => %{"id" => "nested"}})

      assert invite.guild_id == "flat"
    end
  end

  describe "the fields the new endpoints introduced" do
    test "roles granted on accept are parsed into structs" do
      invite =
        Invite.from_raw(%{
          "code" => "a",
          "roles" => [%{"id" => "r1", "name" => "Guest"}, %{"id" => "r2"}]
        })

      assert [%EDA.Role{id: "r1", name: "Guest"}, %EDA.Role{id: "r2"}] = invite.roles
    end

    test "no roles is nil, not an empty list, so 'absent' stays distinguishable" do
      assert Invite.from_raw(%{"code" => "a"}).roles == nil
    end

    test "the approximate counts only appear with with_counts" do
      invite =
        Invite.from_raw(%{
          "code" => "a",
          "approximate_member_count" => 42,
          "approximate_presence_count" => 7
        })

      assert invite.approximate_member_count == 42
      assert invite.approximate_presence_count == 7
      assert Invite.from_raw(%{"code" => "a"}).approximate_member_count == nil
    end
  end

  describe "type/1 and target_type/1" do
    test "every documented invite type" do
      assert Invite.type(%Invite{type: 0}) == :guild
      assert Invite.type(%Invite{type: 1}) == :group_dm
      assert Invite.type(%Invite{type: 2}) == :friend
      assert Invite.type(%{"type" => 2}) == :friend
    end

    test "an absent type is a guild invite — the gateway event omits it" do
      assert Invite.type(%Invite{type: nil}) == :guild
      assert Invite.type(nil) == :guild
    end

    test "an unrecognised type does not crash" do
      assert Invite.type(%Invite{type: 99}) == :unknown
    end

    test "target types name what a voice invite points at" do
      assert Invite.target_type(%Invite{target_type: 1}) == :stream
      assert Invite.target_type(%Invite{target_type: 2}) == :embedded_application
      assert Invite.target_type(%{"target_type" => 1}) == :stream
      assert Invite.target_type(%Invite{target_type: 99}) == :unknown
    end

    test "an ordinary invite has no target type at all" do
      assert Invite.target_type(%Invite{}) == nil
    end
  end

  describe "guest_invite?/1" do
    test "reads the only documented flag" do
      assert Invite.flag_guest_invite() == 1
      assert Invite.guest_invite?(%Invite{flags: 1})
      assert Invite.guest_invite?(%{"flags" => 1})
      assert Invite.guest_invite?(1)
    end

    test "an unset or absent bitfield is false" do
      refute Invite.guest_invite?(%Invite{flags: 0})
      refute Invite.guest_invite?(%Invite{flags: nil})
      refute Invite.guest_invite?(nil)
    end

    test "other bits do not turn it on" do
      refute Invite.guest_invite?(2)
      assert Invite.guest_invite?(3)
    end

    test "the target-users bit is not mistaken for a guest invite" do
      # Observed live: an invite created with target_users comes back with flags: 16.
      refute Invite.guest_invite?(16)
    end
  end

  describe "has_target_users?/1" do
    test "reads the undocumented bit seen on a real invite" do
      assert Invite.flag_has_target_users() == 16
      assert Invite.has_target_users?(%Invite{flags: 16})
      assert Invite.has_target_users?(%{"flags" => 16})
      assert Invite.has_target_users?(16)
    end

    test "an ordinary invite carries no flags key at all" do
      refute Invite.has_target_users?(%Invite{flags: nil})
      refute Invite.has_target_users?(%{"code" => "a"})
      refute Invite.has_target_users?(nil)
    end

    test "the two flags are independent" do
      refute Invite.has_target_users?(1)
      assert Invite.has_target_users?(17)
      assert Invite.guest_invite?(17)
    end
  end

  describe "created_at" do
    test "is parsed — Discord sends it although the object table omits it" do
      invite = Invite.from_raw(%{"code" => "a", "created_at" => "2026-09-19T19:55:22+00:00"})
      assert invite.created_at == "2026-09-19T19:55:22+00:00"
    end
  end

  describe "permanent?/1" do
    test "max_age 0 is Discord's way of saying never expires" do
      assert Invite.permanent?(%Invite{max_age: 0})
      refute Invite.permanent?(%Invite{max_age: 3600})
    end

    test "a REST object with neither max_age nor an expiry is permanent" do
      assert Invite.permanent?(%Invite{expires_at: nil, max_age: nil})
      refute Invite.permanent?(%Invite{expires_at: "2026-09-26T12:00:00Z"})
    end

    test "a raw map is accepted too" do
      assert Invite.permanent?(%{"code" => "a", "max_age" => 0})
    end
  end

  describe "url/1" do
    test "builds the link from a struct, a raw map or a bare code" do
      assert Invite.url(%Invite{code: "abc"}) == "https://discord.gg/abc"
      assert Invite.url(%{"code" => "abc"}) == "https://discord.gg/abc"
      assert Invite.url("abc") == "https://discord.gg/abc"
    end

    test "an invite with no code has no url" do
      assert Invite.url(%Invite{}) == nil
    end
  end

  describe "from_raw/1" do
    test "parses with nested inviter and target_user" do
      raw = %{
        "code" => "abc123",
        "guild_id" => "g1",
        "channel_id" => "ch1",
        "inviter" => %{"id" => "u1", "username" => "alice"},
        "target_user" => %{"id" => "u2", "username" => "bob"},
        "max_age" => 3600,
        "max_uses" => 10,
        "uses" => 2,
        "temporary" => false
      }

      invite = Invite.from_raw(raw)
      assert %Invite{} = invite
      assert invite.code == "abc123"
      assert %EDA.User{id: "u1"} = invite.inviter
      assert %EDA.User{id: "u2"} = invite.target_user
    end

    test "handles nil users" do
      invite = Invite.from_raw(%{"code" => "abc"})
      assert invite.inviter == nil
      assert invite.target_user == nil
    end
  end
end
