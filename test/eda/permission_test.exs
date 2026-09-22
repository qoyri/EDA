defmodule EDA.PermissionTest do
  use ExUnit.Case

  # NOT async — shares ETS cache tables.

  alias EDA.Permission

  import Bitwise

  # ── Test Data Helpers ─────────────────────────────────────────────

  @guild_id "900"
  @owner_id "1"
  @admin_id "2"
  @user_id "3"
  @channel_id "100"
  @voice_channel_id "200"
  @obfuscated_channel_id "perm_obf_300"
  @timed_out_id "perm_timeout_4"
  @role_a_id "10"
  @role_b_id "20"

  defp role_ids_of(user_id) do
    case EDA.Cache.get_member(@guild_id, user_id) do
      nil -> []
      member -> member["roles"] || []
    end
  end

  defp setup_guild(_context) do
    # Clean up any previous test data
    EDA.Cache.Guild.create(%{
      "id" => @guild_id,
      "name" => "Test Guild",
      "owner_id" => @owner_id
    })

    # @everyone role (same ID as guild)
    EDA.Cache.Role.create(@guild_id, %{
      "id" => @guild_id,
      "permissions" => to_string(Permission.to_bitset([:view_channel, :send_messages]))
    })

    # Role A — moderate permissions
    EDA.Cache.Role.create(@guild_id, %{
      "id" => @role_a_id,
      "permissions" => to_string(Permission.to_bitset([:manage_messages, :embed_links]))
    })

    # Role B — admin
    EDA.Cache.Role.create(@guild_id, %{
      "id" => @role_b_id,
      "permissions" => to_string(Permission.to_bitset([:administrator]))
    })

    # Owner member
    EDA.Cache.Member.create(@guild_id, %{
      "user" => %{"id" => @owner_id},
      "roles" => []
    })

    # Admin member (has role B)
    EDA.Cache.Member.create(@guild_id, %{
      "user" => %{"id" => @admin_id},
      "roles" => [@role_b_id]
    })

    # Regular member (has role A)
    EDA.Cache.Member.create(@guild_id, %{
      "user" => %{"id" => @user_id},
      "roles" => [@role_a_id]
    })

    # Timed out member — same roles as @user_id, so only the timeout differs
    EDA.Cache.Member.create(@guild_id, %{
      "user" => %{"id" => @timed_out_id},
      "roles" => [@role_a_id],
      "communication_disabled_until" =>
        DateTime.utc_now() |> DateTime.add(3600, :second) |> DateTime.to_iso8601()
    })

    # Text channel — no overwrites
    EDA.Cache.Channel.create(%{
      "id" => @channel_id,
      "guild_id" => @guild_id,
      "type" => 0,
      "permission_overwrites" => []
    })

    # Voice channel — no overwrites
    EDA.Cache.Channel.create(%{
      "id" => @voice_channel_id,
      "guild_id" => @guild_id,
      "type" => 2,
      "permission_overwrites" => []
    })

    :ok
  end

  # ── Conversion Tests ──────────────────────────────────────────────

  describe "to_bit/1" do
    test "returns correct bit values" do
      assert Permission.to_bit(:administrator) == 1 <<< 3
      assert Permission.to_bit(:view_channel) == 1 <<< 10
      assert Permission.to_bit(:send_messages) == 1 <<< 11
      assert Permission.to_bit(:manage_roles) == 1 <<< 28
    end
  end

  describe "from_bit/1" do
    test "returns flag for known bit" do
      assert {:ok, :administrator} = Permission.from_bit(1 <<< 3)
    end

    test "returns error for unknown bit" do
      assert :error = Permission.from_bit(1 <<< 47)
    end
  end

  describe "to_bitset/1 and to_list/1" do
    test "round-trips" do
      flags = [:view_channel, :send_messages, :administrator]
      bitset = Permission.to_bitset(flags)
      result = Permission.to_list(bitset)
      assert Enum.sort(result) == Enum.sort(flags)
    end

    test "empty list" do
      assert Permission.to_bitset([]) == 0
      assert Permission.to_list(0) == []
    end
  end

  describe "has?/2" do
    test "true when flag is set" do
      bitset = Permission.to_bitset([:view_channel, :send_messages])
      assert Permission.has?(bitset, :view_channel)
      assert Permission.has?(bitset, :send_messages)
    end

    test "false when flag is not set" do
      bitset = Permission.to_bitset([:view_channel])
      refute Permission.has?(bitset, :administrator)
    end
  end

  # ── Guild-Level Permissions ───────────────────────────────────────

  describe "in_guild/2" do
    setup :setup_guild

    test "owner gets ALL permissions" do
      assert {:ok, perms} = Permission.in_guild(@guild_id, @owner_id)
      assert perms == Permission.all()
    end

    test "admin role grants ALL permissions" do
      assert {:ok, perms} = Permission.in_guild(@guild_id, @admin_id)
      assert perms == Permission.all()
    end

    test "regular member gets @everyone + role permissions" do
      assert {:ok, perms} = Permission.in_guild(@guild_id, @user_id)
      assert Permission.has?(perms, :view_channel)
      assert Permission.has?(perms, :send_messages)
      assert Permission.has?(perms, :manage_messages)
      assert Permission.has?(perms, :embed_links)
      refute Permission.has?(perms, :administrator)
      refute Permission.has?(perms, :ban_members)
    end

    test "returns error for missing guild" do
      assert {:error, :guild_not_found} = Permission.in_guild("nonexistent", @user_id)
    end

    test "returns error for missing member" do
      assert {:error, :member_not_found} = Permission.in_guild(@guild_id, "nonexistent")
    end
  end

  describe "for_member/2" do
    setup :setup_guild

    # A member seen through an interaction, never cached: no GUILD_MEMBERS intent needed.
    @uncached_id "perm_for_member_5"

    test "computes from a member struct that is not cached" do
      member =
        EDA.Member.from_raw(%{"user" => %{"id" => @uncached_id}, "roles" => [@role_a_id]})

      assert EDA.Cache.get_member(@guild_id, @uncached_id) == nil
      assert {:ok, perms} = Permission.for_member(member, @guild_id)
      assert Permission.has?(perms, :manage_messages)
      assert Permission.has?(perms, :send_messages)
      refute Permission.has?(perms, :administrator)
    end

    test "takes a raw member map, as an interaction payload carries it" do
      raw = %{"user" => %{"id" => @uncached_id}, "roles" => [@role_b_id]}
      assert {:ok, perms} = Permission.for_member(raw, @guild_id)
      assert perms == Permission.all()
    end

    test "agrees with in_guild/2 for a cached member, the owner included" do
      for user_id <- [@owner_id, @admin_id, @user_id] do
        member = EDA.Member.from_raw(EDA.Cache.get_member(@guild_id, user_id))
        assert Permission.for_member(member, @guild_id) == Permission.in_guild(@guild_id, user_id)
      end
    end

    test "errors on a missing guild, or a member without a user" do
      member = EDA.Member.from_raw(%{"user" => %{"id" => @uncached_id}, "roles" => []})
      assert {:error, :guild_not_found} = Permission.for_member(member, "nonexistent")
      assert {:error, :member_without_user} = Permission.for_member(%EDA.Member{}, @guild_id)
    end
  end

  # ── Channel-Level Permissions ─────────────────────────────────────

  describe "in_channel/3 — no overwrites" do
    setup :setup_guild

    test "owner gets ALL permissions in any channel" do
      assert {:ok, perms} = Permission.in_channel(@guild_id, @owner_id, @channel_id)
      assert perms == Permission.all()
    end

    test "admin gets ALL permissions in any channel" do
      assert {:ok, perms} = Permission.in_channel(@guild_id, @admin_id, @channel_id)
      assert perms == Permission.all()
    end

    test "regular member inherits guild perms in channel" do
      assert {:ok, perms} = Permission.in_channel(@guild_id, @user_id, @channel_id)
      assert Permission.has?(perms, :view_channel)
      assert Permission.has?(perms, :send_messages)
      assert Permission.has?(perms, :manage_messages)
    end

    test "returns error for missing channel" do
      assert {:error, :channel_not_found} = Permission.in_channel(@guild_id, @user_id, "nope")
    end
  end

  describe "in_channel/3 — timed out member" do
    setup :setup_guild

    test "keeps at most VIEW_CHANNEL and READ_MESSAGE_HISTORY" do
      assert {:ok, perms} = Permission.in_channel(@guild_id, @timed_out_id, @channel_id)

      # The gate restricts, so the result is the intersection of what the member had
      # with the two retained permissions — never more.
      assert Permission.to_list(perms) -- [:view_channel, :read_message_history] == []

      assert Permission.has?(perms, :view_channel)
      refute Permission.has?(perms, :send_messages)
      refute Permission.has?(perms, :manage_messages)
    end

    test "the gate cannot grant a permission the member never had" do
      # @everyone in this fixture does not grant read_message_history, so the timeout
      # must not conjure it.
      {:ok, before} = Permission.in_channel(@guild_id, @user_id, @channel_id)
      {:ok, muted} = Permission.in_channel(@guild_id, @timed_out_id, @channel_id)

      refute Permission.has?(before, :read_message_history)
      refute Permission.has?(muted, :read_message_history)
      assert Bitwise.band(muted, before) == muted
    end

    test "an identical member without the timeout keeps everything" do
      {:ok, normal} = Permission.in_channel(@guild_id, @user_id, @channel_id)
      {:ok, muted} = Permission.in_channel(@guild_id, @timed_out_id, @channel_id)

      assert Permission.has?(normal, :send_messages)
      refute Permission.has?(muted, :send_messages)
    end

    test "has_permission?/4 answers false, which is the point" do
      refute Permission.has_permission?(@guild_id, @timed_out_id, @channel_id, :send_messages)
      assert Permission.has_permission?(@guild_id, @timed_out_id, @channel_id, :view_channel)
    end

    test "an expired timeout is not a timeout" do
      EDA.Cache.Member.create(@guild_id, %{
        "user" => %{"id" => "perm_expired_5"},
        "roles" => [@role_a_id],
        "communication_disabled_until" =>
          DateTime.utc_now() |> DateTime.add(-60, :second) |> DateTime.to_iso8601()
      })

      assert Permission.has_permission?(@guild_id, "perm_expired_5", @channel_id, :send_messages)
    end

    test "owner and admin are exempt — Discord refuses to time them out at all" do
      for id <- [@owner_id, @admin_id] do
        EDA.Cache.Member.create(@guild_id, %{
          "user" => %{"id" => id},
          "roles" => role_ids_of(id),
          "communication_disabled_until" =>
            DateTime.utc_now() |> DateTime.add(3600, :second) |> DateTime.to_iso8601()
        })

        assert {:ok, perms} = Permission.in_channel(@guild_id, id, @channel_id)
        assert perms == Permission.all()
      end
    end

    test "voice: a timed out member loses CONNECT and is gated to zero" do
      assert {:ok, 0} = Permission.in_channel(@guild_id, @timed_out_id, @voice_channel_id)
    end
  end

  describe "explain/3" do
    setup :setup_guild

    test "agrees with in_channel/3 on the effective result" do
      {:ok, perms} = Permission.in_channel(@guild_id, @user_id, @channel_id)
      {:ok, why} = Permission.explain(@guild_id, @user_id, @channel_id)

      assert why.effective == perms
    end

    test "lists the derivation in order" do
      {:ok, why} = Permission.explain(@guild_id, @user_id, @channel_id)

      assert Enum.map(why.steps, & &1.stage) == [
               :role_base,
               :everyone_overwrite,
               :role_overwrites,
               :member_overwrite
             ]

      assert why.base == why.steps |> hd() |> Map.fetch!(:result)
    end

    test "names the gate that denied access" do
      {:ok, why} = Permission.explain(@guild_id, @timed_out_id, @voice_channel_id)

      assert why.denied_by == :no_connect
      assert :timed_out in why.gates
      assert why.effective == 0
    end

    test "records the timeout gate and what survived it" do
      {:ok, why} = Permission.explain(@guild_id, @timed_out_id, @channel_id)

      assert why.gates == [:timed_out]
      assert why.denied_by == nil

      gate = Enum.find(why.steps, &(&1[:gate] == :timed_out))

      assert Permission.has?(gate.result, :view_channel)
      refute Permission.has?(gate.result, :send_messages)
    end

    test "owner and admin short-circuit in a single step" do
      {:ok, owner} = Permission.explain(@guild_id, @owner_id, @channel_id)
      {:ok, admin} = Permission.explain(@guild_id, @admin_id, @channel_id)

      assert Enum.map(owner.steps, & &1.stage) == [:owner]
      assert Enum.map(admin.steps, & &1.stage) == [:administrator]
      assert owner.effective == Permission.all()
      assert admin.effective == Permission.all()
    end

    test "surfaces what an overwrite denied" do
      EDA.Cache.Channel.create(%{
        "id" => "perm_explain_ch",
        "guild_id" => @guild_id,
        "type" => 0,
        "permission_overwrites" => [
          %{
            "id" => @guild_id,
            "type" => 0,
            "allow" => "0",
            "deny" => to_string(Permission.to_bit(:send_messages))
          }
        ]
      })

      {:ok, why} = Permission.explain(@guild_id, @user_id, "perm_explain_ch")

      denied =
        why.steps
        |> Enum.find(&(&1.stage == :everyone_overwrite))
        |> Map.fetch!(:deny)
        |> Permission.to_list()

      assert :send_messages in denied
      refute Permission.has?(why.effective, :send_messages)
    end

    test "propagates the same errors as in_channel/3" do
      assert {:error, :channel_not_found} = Permission.explain(@guild_id, @user_id, "nope")
      assert {:error, :member_not_found} = Permission.explain(@guild_id, "nobody", @channel_id)
    end
  end

  describe "in_channel/3 — obfuscated channel" do
    setup :setup_guild

    setup do
      # Exactly what Discord dispatches for a channel the bot cannot view: the real
      # metadata is stripped and a single @everyone VIEW_CHANNEL deny is injected.
      EDA.Cache.Channel.create(%{
        "id" => @obfuscated_channel_id,
        "guild_id" => @guild_id,
        "type" => 0,
        "name" => EDA.Channel.obfuscated_name(),
        "flags" => EDA.Channel.flag_obfuscated(),
        "permission_overwrites" => [
          %{
            "id" => @guild_id,
            "type" => 0,
            "allow" => "0",
            "deny" => to_string(Permission.to_bit(:view_channel))
          }
        ]
      })

      :ok
    end

    test "reports :channel_obfuscated rather than computing from the synthetic overwrite" do
      assert {:error, :channel_obfuscated} =
               Permission.in_channel(@guild_id, @user_id, @obfuscated_channel_id)
    end

    test "applies to privileged members too — the bot cannot see the channel either way" do
      assert {:error, :channel_obfuscated} =
               Permission.in_channel(@guild_id, @owner_id, @obfuscated_channel_id)

      assert {:error, :channel_obfuscated} =
               Permission.in_channel(@guild_id, @admin_id, @obfuscated_channel_id)
    end

    test "has_permission?/4 is false, like any other error" do
      refute Permission.has_permission?(
               @guild_id,
               @user_id,
               @obfuscated_channel_id,
               :view_channel
             )

      refute Permission.has_permission?(
               @guild_id,
               @user_id,
               @obfuscated_channel_id,
               :send_messages
             )
    end

    test "channels without the flag are unaffected" do
      assert {:ok, _perms} = Permission.in_channel(@guild_id, @user_id, @channel_id)
    end
  end

  describe "in_channel/3 — @everyone overwrite (tier 1)" do
    setup :setup_guild

    test "denies @everyone send_messages" do
      EDA.Cache.Channel.update(@channel_id, %{
        "permission_overwrites" => [
          %{
            "id" => @guild_id,
            "type" => 0,
            "allow" => "0",
            "deny" => to_string(Permission.to_bit(:send_messages))
          }
        ]
      })

      assert {:ok, perms} = Permission.in_channel(@guild_id, @user_id, @channel_id)
      refute Permission.has?(perms, :send_messages)
      assert Permission.has?(perms, :view_channel)
    end
  end

  describe "in_channel/3 — role overwrite (tier 2) overrides @everyone" do
    setup :setup_guild

    test "role allow overrides @everyone deny" do
      EDA.Cache.Channel.update(@channel_id, %{
        "permission_overwrites" => [
          # @everyone: deny send_messages
          %{
            "id" => @guild_id,
            "type" => 0,
            "allow" => "0",
            "deny" => to_string(Permission.to_bit(:send_messages))
          },
          # Role A: allow send_messages
          %{
            "id" => @role_a_id,
            "type" => 0,
            "allow" => to_string(Permission.to_bit(:send_messages)),
            "deny" => "0"
          }
        ]
      })

      assert {:ok, perms} = Permission.in_channel(@guild_id, @user_id, @channel_id)
      assert Permission.has?(perms, :send_messages)
    end
  end

  describe "in_channel/3 — member overwrite (tier 3) overrides roles" do
    setup :setup_guild

    test "member deny overrides role allow" do
      EDA.Cache.Channel.update(@channel_id, %{
        "permission_overwrites" => [
          # Role A: allow send_messages
          %{
            "id" => @role_a_id,
            "type" => 0,
            "allow" => to_string(Permission.to_bit(:send_messages)),
            "deny" => "0"
          },
          # Member: deny send_messages
          %{
            "id" => @user_id,
            "type" => 1,
            "allow" => "0",
            "deny" => to_string(Permission.to_bit(:send_messages))
          }
        ]
      })

      assert {:ok, perms} = Permission.in_channel(@guild_id, @user_id, @channel_id)
      refute Permission.has?(perms, :send_messages)
    end

    test "member allow overrides role deny" do
      EDA.Cache.Channel.update(@channel_id, %{
        "permission_overwrites" => [
          # Role A: deny embed_links
          %{
            "id" => @role_a_id,
            "type" => 0,
            "allow" => "0",
            "deny" => to_string(Permission.to_bit(:embed_links))
          },
          # Member: allow embed_links
          %{
            "id" => @user_id,
            "type" => 1,
            "allow" => to_string(Permission.to_bit(:embed_links)),
            "deny" => "0"
          }
        ]
      })

      assert {:ok, perms} = Permission.in_channel(@guild_id, @user_id, @channel_id)
      assert Permission.has?(perms, :embed_links)
    end
  end

  describe "in_channel/3 — full 3-tier cascade" do
    setup :setup_guild

    test "@everyone deny → role allow → member deny" do
      EDA.Cache.Channel.update(@channel_id, %{
        "permission_overwrites" => [
          # @everyone: deny send_messages + embed_links
          %{
            "id" => @guild_id,
            "type" => 0,
            "allow" => "0",
            "deny" =>
              to_string(Permission.to_bit(:send_messages) ||| Permission.to_bit(:embed_links))
          },
          # Role A: allow send_messages
          %{
            "id" => @role_a_id,
            "type" => 0,
            "allow" => to_string(Permission.to_bit(:send_messages)),
            "deny" => "0"
          },
          # Member: deny send_messages again
          %{
            "id" => @user_id,
            "type" => 1,
            "allow" => "0",
            "deny" => to_string(Permission.to_bit(:send_messages))
          }
        ]
      })

      assert {:ok, perms} = Permission.in_channel(@guild_id, @user_id, @channel_id)
      # send_messages: @everyone denied → role allowed → member denied → DENIED
      refute Permission.has?(perms, :send_messages)
      # embed_links: @everyone denied → no role override → no member override → DENIED
      refute Permission.has?(perms, :embed_links)
      # view_channel: not touched by any overwrite → still from guild base
      assert Permission.has?(perms, :view_channel)
    end
  end

  # ── Access Gates ──────────────────────────────────────────────────

  describe "VIEW_CHANNEL access gate" do
    setup :setup_guild

    test "returns 0 when VIEW_CHANNEL is denied" do
      EDA.Cache.Channel.update(@channel_id, %{
        "permission_overwrites" => [
          %{
            "id" => @guild_id,
            "type" => 0,
            "allow" => "0",
            "deny" => to_string(Permission.to_bit(:view_channel))
          }
        ]
      })

      assert {:ok, 0} = Permission.in_channel(@guild_id, @user_id, @channel_id)
    end

    test "admin bypasses VIEW_CHANNEL gate" do
      EDA.Cache.Channel.update(@channel_id, %{
        "permission_overwrites" => [
          %{
            "id" => @guild_id,
            "type" => 0,
            "allow" => "0",
            "deny" => to_string(Permission.to_bit(:view_channel))
          }
        ]
      })

      assert {:ok, perms} = Permission.in_channel(@guild_id, @admin_id, @channel_id)
      assert perms == Permission.all()
    end
  end

  describe "VOICE_CONNECT access gate" do
    setup :setup_guild

    test "returns 0 in voice channel when CONNECT is denied" do
      EDA.Cache.Channel.update(@voice_channel_id, %{
        "permission_overwrites" => [
          %{
            "id" => @guild_id,
            "type" => 0,
            "allow" => "0",
            "deny" => to_string(Permission.to_bit(:connect))
          }
        ]
      })

      assert {:ok, 0} = Permission.in_channel(@guild_id, @user_id, @voice_channel_id)
    end

    test "CONNECT gate does not apply to text channels" do
      # Text channel without connect — should still work fine
      EDA.Cache.Channel.update(@channel_id, %{
        "permission_overwrites" => [
          %{
            "id" => @guild_id,
            "type" => 0,
            "allow" => "0",
            "deny" => to_string(Permission.to_bit(:connect))
          }
        ]
      })

      assert {:ok, perms} = Permission.in_channel(@guild_id, @user_id, @channel_id)
      assert perms != 0
      assert Permission.has?(perms, :view_channel)
    end
  end

  # ── Convenience Functions ─────────────────────────────────────────

  describe "has_permission?/4" do
    setup :setup_guild

    test "returns true when permission is granted" do
      assert Permission.has_permission?(@guild_id, @user_id, @channel_id, :send_messages)
    end

    test "returns false when permission is denied" do
      refute Permission.has_permission?(@guild_id, @user_id, @channel_id, :administrator)
    end

    test "returns false for missing data" do
      refute Permission.has_permission?("nope", @user_id, @channel_id, :send_messages)
    end
  end

  describe "has_guild_permission?/3" do
    setup :setup_guild

    test "returns true for owner" do
      assert Permission.has_guild_permission?(@guild_id, @owner_id, :ban_members)
    end

    test "returns false when not granted" do
      refute Permission.has_guild_permission?(@guild_id, @user_id, :ban_members)
    end
  end

  # ── Edge Cases ────────────────────────────────────────────────────

  describe "edge cases" do
    setup :setup_guild

    test "member with no roles gets only @everyone permissions" do
      EDA.Cache.Member.create(@guild_id, %{
        "user" => %{"id" => "99"},
        "roles" => []
      })

      assert {:ok, perms} = Permission.in_guild(@guild_id, "99")
      assert Permission.has?(perms, :view_channel)
      assert Permission.has?(perms, :send_messages)
      refute Permission.has?(perms, :manage_messages)
    end

    test "permissions field as integer (not string) works" do
      EDA.Cache.Role.create(@guild_id, %{
        "id" => "30",
        "permissions" => Permission.to_bitset([:kick_members])
      })

      EDA.Cache.Member.create(@guild_id, %{
        "user" => %{"id" => "98"},
        "roles" => ["30"]
      })

      assert {:ok, perms} = Permission.in_guild(@guild_id, "98")
      assert Permission.has?(perms, :kick_members)
    end

    test "channel with no permission_overwrites key works" do
      EDA.Cache.Channel.create(%{
        "id" => "300",
        "guild_id" => @guild_id,
        "type" => 0
      })

      assert {:ok, perms} = Permission.in_channel(@guild_id, @user_id, "300")
      assert Permission.has?(perms, :view_channel)
    end

    test "stage channel (type 13) applies CONNECT gate" do
      EDA.Cache.Channel.create(%{
        "id" => "400",
        "guild_id" => @guild_id,
        "type" => 13,
        "permission_overwrites" => [
          %{
            "id" => @guild_id,
            "type" => 0,
            "allow" => "0",
            "deny" => to_string(Permission.to_bit(:connect))
          }
        ]
      })

      assert {:ok, 0} = Permission.in_channel(@guild_id, @user_id, "400")
    end
  end
end
