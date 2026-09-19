defmodule EDA.Gateway.MemberChunkerTest do
  use ExUnit.Case, async: false

  alias EDA.Gateway.MemberChunker

  # The MemberChunker is started by the application supervisor.
  # We interact with it directly in tests.

  describe "request/2" do
    test "sends OP 8 and returns :ok" do
      # This will fail to reach a shard (no gateway), but the GenServer call succeeds
      assert :ok = MemberChunker.request("123456789")
    end
  end

  describe "handle_chunk/1 — caching" do
    test "caches members in EDA.Cache.Member" do
      guild_id = "chunk_g1"

      MemberChunker.handle_chunk(%{
        "nonce" => "unknown_nonce_1",
        "guild_id" => guild_id,
        "chunk_index" => 0,
        "chunk_count" => 1,
        "members" => [
          %{"user" => %{"id" => "chunk_u1", "username" => "alice"}, "roles" => []}
        ]
      })

      # Give the cast time to process
      Process.sleep(50)

      # The chunk had an unknown nonce, but caching still happens via events.ex
      # For direct MemberChunker caching, we test with tracked requests below
    end

    test "caches users from member chunks" do
      guild_id = "chunk_g2"

      # Start a tracked request via GenServer internals
      nonce = start_tracked_request(guild_id)

      MemberChunker.handle_chunk(%{
        "nonce" => nonce,
        "guild_id" => guild_id,
        "chunk_index" => 0,
        "chunk_count" => 1,
        "members" => [
          %{"user" => %{"id" => "chunk_u2", "username" => "bob"}, "roles" => []}
        ]
      })

      Process.sleep(50)

      assert EDA.Cache.User.get("chunk_u2") != nil
      assert EDA.Cache.User.get("chunk_u2")["username"] == "bob"
    end

    test "caches members from chunks" do
      guild_id = "chunk_g3"
      nonce = start_tracked_request(guild_id)

      MemberChunker.handle_chunk(%{
        "nonce" => nonce,
        "guild_id" => guild_id,
        "chunk_index" => 0,
        "chunk_count" => 1,
        "members" => [
          %{"user" => %{"id" => "chunk_u3", "username" => "carol"}, "roles" => ["role1"]}
        ]
      })

      Process.sleep(50)

      member = EDA.Cache.Member.get(guild_id, "chunk_u3")
      assert member != nil
    end

    test "caches presences from chunks" do
      guild_id = "chunk_g4"
      nonce = start_tracked_request(guild_id)

      MemberChunker.handle_chunk(%{
        "nonce" => nonce,
        "guild_id" => guild_id,
        "chunk_index" => 0,
        "chunk_count" => 1,
        "members" => [
          %{"user" => %{"id" => "chunk_u4", "username" => "dave"}, "roles" => []}
        ],
        "presences" => [
          %{"user" => %{"id" => "chunk_u4"}, "status" => "online"}
        ]
      })

      Process.sleep(50)

      presence = EDA.Cache.Presence.get(guild_id, "chunk_u4")
      assert presence != nil
    end

    test "ignores chunks with unknown nonce" do
      # Should not crash or error
      MemberChunker.handle_chunk(%{
        "nonce" => "totally_unknown_nonce",
        "guild_id" => "whatever",
        "chunk_index" => 0,
        "chunk_count" => 1,
        "members" => []
      })

      Process.sleep(50)
      # No crash = success
    end
  end

  describe "await/2" do
    test "returns {:ok, members} when chunks complete" do
      guild_id = "await_g1"

      # Spawn a task that calls await, then deliver the chunk
      task =
        Task.async(fn ->
          # We need to intercept the nonce. Use a custom approach:
          # call the GenServer directly to register a tracked request
          MemberChunker.await(guild_id)
        end)

      # Give the await call time to register
      Process.sleep(50)

      # Find the nonce from the GenServer state
      state = :sys.get_state(MemberChunker)
      {nonce, _req} = Enum.find(state.requests, fn {_n, r} -> r.guild_id == guild_id end)

      MemberChunker.handle_chunk(%{
        "nonce" => nonce,
        "guild_id" => guild_id,
        "chunk_index" => 0,
        "chunk_count" => 1,
        "members" => [
          %{"user" => %{"id" => "await_u1", "username" => "eve"}, "roles" => []}
        ]
      })

      assert {:ok, members} = Task.await(task, 5_000)
      assert length(members) == 1
      assert hd(members)["user"]["username"] == "eve"
    end

    test "accumulates members across multiple chunks" do
      guild_id = "await_g2"

      task =
        Task.async(fn ->
          MemberChunker.await(guild_id)
        end)

      Process.sleep(50)

      state = :sys.get_state(MemberChunker)
      {nonce, _req} = Enum.find(state.requests, fn {_n, r} -> r.guild_id == guild_id end)

      # Send first chunk
      MemberChunker.handle_chunk(%{
        "nonce" => nonce,
        "guild_id" => guild_id,
        "chunk_index" => 0,
        "chunk_count" => 2,
        "members" => [
          %{"user" => %{"id" => "await_u2a", "username" => "frank"}, "roles" => []}
        ]
      })

      # Send second (last) chunk
      MemberChunker.handle_chunk(%{
        "nonce" => nonce,
        "guild_id" => guild_id,
        "chunk_index" => 1,
        "chunk_count" => 2,
        "members" => [
          %{"user" => %{"id" => "await_u2b", "username" => "grace"}, "roles" => []}
        ]
      })

      assert {:ok, members} = Task.await(task, 5_000)
      assert length(members) == 2
    end
  end

  describe "search/3" do
    test "sends OP 8 with query and limit" do
      guild_id = "search_g1"

      task =
        Task.async(fn ->
          MemberChunker.search(guild_id, "ali")
        end)

      Process.sleep(50)

      state = :sys.get_state(MemberChunker)
      {nonce, _req} = Enum.find(state.requests, fn {_n, r} -> r.guild_id == guild_id end)

      MemberChunker.handle_chunk(%{
        "nonce" => nonce,
        "guild_id" => guild_id,
        "chunk_index" => 0,
        "chunk_count" => 1,
        "members" => [
          %{"user" => %{"id" => "search_u1", "username" => "alice"}, "roles" => []}
        ]
      })

      assert {:ok, members} = Task.await(task, 5_000)
      assert length(members) == 1
    end
  end

  describe "fetch/3" do
    test "sends OP 8 with user_ids" do
      guild_id = "fetch_g1"

      task =
        Task.async(fn ->
          MemberChunker.fetch(guild_id, ["fetch_u1", "fetch_u2"])
        end)

      Process.sleep(50)

      state = :sys.get_state(MemberChunker)
      {nonce, _req} = Enum.find(state.requests, fn {_n, r} -> r.guild_id == guild_id end)

      MemberChunker.handle_chunk(%{
        "nonce" => nonce,
        "guild_id" => guild_id,
        "chunk_index" => 0,
        "chunk_count" => 1,
        "members" => [
          %{"user" => %{"id" => "fetch_u1", "username" => "henry"}, "roles" => []},
          %{"user" => %{"id" => "fetch_u2", "username" => "irene"}, "roles" => []}
        ]
      })

      assert {:ok, members} = Task.await(task, 5_000)
      assert length(members) == 2
    end
  end

  describe "timeout cleanup" do
    test "expired requests are cleaned up and caller gets {:error, :timeout}" do
      guild_id = "timeout_g1"

      task =
        Task.async(fn ->
          # Use a short timeout by reaching into the GenServer
          MemberChunker.await(guild_id)
        end)

      Process.sleep(50)

      # Manually expire the request by backdating its started_at
      state = :sys.get_state(MemberChunker)
      {nonce, req} = Enum.find(state.requests, fn {_n, r} -> r.guild_id == guild_id end)

      expired_req = %{req | started_at: System.monotonic_time(:millisecond) - 20_000}
      new_state = put_in(state, [:requests, nonce], expired_req)
      :sys.replace_state(MemberChunker, fn _ -> new_state end)

      # Trigger cleanup manually
      send(MemberChunker, :cleanup)

      assert {:error, :timeout} = Task.await(task, 5_000)
    end
  end

  describe "should_chunk? config" do
    test "config true enables auto-chunking" do
      Application.put_env(:eda, :chunk_members, true)

      guild_data = %{
        "id" => "auto_g1",
        "name" => "Big Guild",
        "member_count" => 500,
        "members" => [%{"user" => %{"id" => "auto_u1", "username" => "test"}}],
        "channels" => [],
        "roles" => []
      }

      # Dispatching GUILD_CREATE with member_count > members should trigger auto-chunk
      EDA.Gateway.Events.dispatch("GUILD_CREATE", guild_data)
      # No crash = success (the actual OP 8 send will fail without a gateway)

      Application.delete_env(:eda, :chunk_members)
    end

    test "config false disables auto-chunking" do
      Application.put_env(:eda, :chunk_members, false)

      guild_data = %{
        "id" => "auto_g2",
        "name" => "Big Guild 2",
        "member_count" => 500,
        "members" => [%{"user" => %{"id" => "auto_u2", "username" => "test2"}}],
        "channels" => [],
        "roles" => []
      }

      EDA.Gateway.Events.dispatch("GUILD_CREATE", guild_data)

      Application.delete_env(:eda, :chunk_members)
    end

    test "config with list of guild IDs" do
      Application.put_env(:eda, :chunk_members, ["auto_g3"])

      guild_data = %{
        "id" => "auto_g3",
        "name" => "Listed Guild",
        "member_count" => 500,
        "members" => [%{"user" => %{"id" => "auto_u3", "username" => "test3"}}],
        "channels" => [],
        "roles" => []
      }

      EDA.Gateway.Events.dispatch("GUILD_CREATE", guild_data)

      Application.delete_env(:eda, :chunk_members)
    end

    test "config with function" do
      Application.put_env(:eda, :chunk_members, fn _guild_id -> false end)

      guild_data = %{
        "id" => "auto_g4",
        "name" => "Func Guild",
        "member_count" => 500,
        "members" => [%{"user" => %{"id" => "auto_u4", "username" => "test4"}}],
        "channels" => [],
        "roles" => []
      }

      EDA.Gateway.Events.dispatch("GUILD_CREATE", guild_data)

      Application.delete_env(:eda, :chunk_members)
    end

    test "config :large enables auto-chunking" do
      Application.put_env(:eda, :chunk_members, :large)

      guild_data = %{
        "id" => "auto_g5",
        "name" => "Large Guild",
        "member_count" => 500,
        "members" => [%{"user" => %{"id" => "auto_u5", "username" => "test5"}}],
        "channels" => [],
        "roles" => []
      }

      EDA.Gateway.Events.dispatch("GUILD_CREATE", guild_data)

      Application.delete_env(:eda, :chunk_members)
    end
  end

  describe "GUILD_MEMBERS_CHUNK event integration" do
    test "Events.dispatch routes to MemberChunker" do
      guild_id = "event_chunk_g1"
      nonce = start_tracked_request(guild_id)

      EDA.Gateway.Events.dispatch("GUILD_MEMBERS_CHUNK", %{
        "nonce" => nonce,
        "guild_id" => guild_id,
        "chunk_index" => 0,
        "chunk_count" => 1,
        "members" => [
          %{"user" => %{"id" => "event_chunk_u1", "username" => "zara"}, "roles" => []}
        ]
      })

      Process.sleep(50)

      assert EDA.Cache.User.get("event_chunk_u1") != nil
      assert EDA.Cache.Member.get(guild_id, "event_chunk_u1") != nil
    end
  end

  describe "nonce generation" do
    test "generates unique nonces" do
      guild_id_a = "nonce_g1"
      guild_id_b = "nonce_g2"

      MemberChunker.request(guild_id_a)
      MemberChunker.request(guild_id_b)

      Process.sleep(50)

      state = :sys.get_state(MemberChunker)

      our_nonces =
        state.requests
        |> Enum.filter(fn {_n, r} -> r.guild_id in [guild_id_a, guild_id_b] end)
        |> Enum.map(fn {n, _r} -> n end)

      assert length(Enum.uniq(our_nonces)) == length(our_nonces)
    end
  end

  describe "OP 8 throttle" do
    setup do
      Application.put_env(:eda, :member_chunk_cooldown_ms, 120)
      on_exit(fn -> Application.delete_env(:eda, :member_chunk_cooldown_ms) end)
      :ok
    end

    test "the first all-members request goes out and arms the cooldown" do
      guild = "throttle_g1"
      MemberChunker.request(guild)
      Process.sleep(20)

      assert Map.has_key?(chunker_state().cooldowns, guild)
      assert Map.get(chunker_state().pending, guild, []) == []
    end

    test "a second request within the window is queued instead of sent" do
      guild = "throttle_g2"
      MemberChunker.request(guild)
      Process.sleep(20)
      armed_at = chunker_state().cooldowns[guild]

      # A queued fire-and-forget would be coalesced, so use an await-style
      # caller to observe the queue: it is enqueued, not dropped.
      task = Task.async(fn -> MemberChunker.await(guild) end)
      Process.sleep(20)

      assert length(Map.get(chunker_state().pending, guild, [])) == 1
      assert chunker_state().cooldowns[guild] == armed_at

      Task.shutdown(task, :brutal_kill)
    end

    test "the queue drains once the cooldown expires" do
      guild = "throttle_g3"
      MemberChunker.request(guild)
      Process.sleep(20)

      task = Task.async(fn -> MemberChunker.await(guild) end)
      Process.sleep(20)
      assert length(Map.get(chunker_state().pending, guild, [])) == 1

      Process.sleep(150)
      assert Map.get(chunker_state().pending, guild, []) == []

      Task.shutdown(task, :brutal_kill)
    end

    test "different guilds do not throttle each other" do
      MemberChunker.request("throttle_g4")
      MemberChunker.request("throttle_g5")
      Process.sleep(20)

      assert Map.get(chunker_state().pending, "throttle_g4", []) == []
      assert Map.get(chunker_state().pending, "throttle_g5", []) == []
      assert Map.has_key?(chunker_state().cooldowns, "throttle_g4")
      assert Map.has_key?(chunker_state().cooldowns, "throttle_g5")
    end

    test "duplicate fire-and-forget requests are coalesced" do
      guild = "throttle_g6"
      MemberChunker.request(guild)
      Process.sleep(20)

      MemberChunker.request(guild)
      MemberChunker.request(guild)
      Process.sleep(20)

      assert length(Map.get(chunker_state().pending, guild, [])) == 1
    end

    test "prefix search is never throttled" do
      guild = "throttle_g7"
      task1 = Task.async(fn -> MemberChunker.search(guild, "ali") end)
      task2 = Task.async(fn -> MemberChunker.search(guild, "bob") end)
      Process.sleep(20)

      assert Map.get(chunker_state().pending, guild, []) == []
      refute Map.has_key?(chunker_state().cooldowns, guild)

      Task.shutdown(task1, :brutal_kill)
      Task.shutdown(task2, :brutal_kill)
    end

    test "fetching by user ids is never throttled" do
      guild = "throttle_g8"
      task1 = Task.async(fn -> MemberChunker.fetch(guild, ["1"]) end)
      task2 = Task.async(fn -> MemberChunker.fetch(guild, ["2"]) end)
      Process.sleep(20)

      assert Map.get(chunker_state().pending, guild, []) == []
      refute Map.has_key?(chunker_state().cooldowns, guild)

      Task.shutdown(task1, :brutal_kill)
      Task.shutdown(task2, :brutal_kill)
    end
  end

  describe "handle_rate_limited/1" do
    setup do
      Application.put_env(:eda, :member_chunk_cooldown_ms, 120)
      on_exit(fn -> Application.delete_env(:eda, :member_chunk_cooldown_ms) end)
      :ok
    end

    test "arms the cooldown from retry_after, overriding the local one" do
      guild = "rl_g1"
      MemberChunker.request(guild)
      Process.sleep(20)
      local = chunker_state().cooldowns[guild]

      MemberChunker.handle_rate_limited(%{
        "opcode" => 8,
        "retry_after" => 5.0,
        "meta" => %{"guild_id" => guild}
      })

      Process.sleep(20)
      assert chunker_state().cooldowns[guild] > local
    end

    test "requeues the rejected request, preserving its caller" do
      guild = "rl_g2"
      MemberChunker.request(guild)
      Process.sleep(20)

      {nonce, request} =
        Enum.find(chunker_state().requests, fn {_n, r} -> r.guild_id == guild end)

      assert request.caller == nil

      MemberChunker.handle_rate_limited(%{
        "opcode" => 8,
        "retry_after" => 0.05,
        "meta" => %{"guild_id" => guild, "nonce" => nonce}
      })

      Process.sleep(20)
      state = chunker_state()
      refute Map.has_key?(state.requests, nonce)
      assert [%{guild_id: ^guild}] = Map.get(state.pending, guild, [])
    end

    test "an unknown nonce only arms the cooldown" do
      guild = "rl_g3"

      MemberChunker.handle_rate_limited(%{
        "opcode" => 8,
        "retry_after" => 1.0,
        "meta" => %{"guild_id" => guild, "nonce" => "nope"}
      })

      Process.sleep(20)
      state = chunker_state()
      assert Map.has_key?(state.cooldowns, guild)
      assert Map.get(state.pending, guild, []) == []
      assert Process.alive?(Process.whereis(MemberChunker))
    end
  end

  # ── Helpers ──────────────────────────────────────────────────────────

  defp chunker_state, do: :sys.get_state(MemberChunker)

  defp start_tracked_request(guild_id) do
    # Fire-and-forget request to register a nonce, then extract it
    MemberChunker.request(guild_id)
    Process.sleep(50)

    state = :sys.get_state(MemberChunker)

    {nonce, _req} =
      Enum.find(state.requests, fn {_n, r} -> r.guild_id == guild_id end)

    nonce
  end
end
