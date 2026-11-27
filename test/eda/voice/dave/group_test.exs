defmodule EDA.Voice.Dave.GroupTest do
  # Real DAVE groups of several sessions, led through a call by EDA.Test.DaveGateway, which plays
  # Discord's voice gateway. What is checked is what a member of a call observes: who can be
  # heard by whom, and when.
  use ExUnit.Case, async: true

  alias EDA.Test.DaveGateway, as: Gateway
  alias EDA.Voice.Dave.Manager

  @alice 1_000_000_000_000_001
  @bob 1_000_000_000_000_002
  @carol 1_000_000_000_000_003

  @opus <<0x78, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12>>
  @silence <<0xF8, 0xFF, 0xFE>>

  # A group of the given users, the first of them creating it.
  defp call([creator | joiners] = users) do
    gateway = Enum.reduce(users, Gateway.new(), &Gateway.connect(&2, &1))
    Gateway.change(gateway, committer: creator, add: joiners)
  end

  defp ready?(gateway, user_id), do: Manager.ready?(Gateway.member(gateway, user_id))

  # `sender` is heard by `receiver`: what it encrypts is not the frame itself, and decrypts to it.
  defp assert_heard(gateway, sender, receiver, frame \\ @opus) do
    assert {:ok, encrypted} = Gateway.encrypt(gateway, sender, frame)
    refute encrypted == frame
    assert {:ok, ^frame} = Gateway.decrypt(gateway, receiver, sender, encrypted)
  end

  describe "forming a group" do
    test "two members hear each other" do
      gateway = call([@alice, @bob])

      assert ready?(gateway, @alice)
      assert ready?(gateway, @bob)
      assert_heard(gateway, @alice, @bob)
      assert_heard(gateway, @bob, @alice)
    end

    test "a group created as transition 0 is not acknowledged, and counts as executed" do
      gateway = call([@alice, @bob])

      refute Enum.any?(Gateway.sent(gateway, @alice), &match?({:ready, _}, &1))
      refute Enum.any?(Gateway.sent(gateway, @bob), &match?({:ready, _}, &1))

      for user <- [@alice, @bob] do
        manager = Gateway.member(gateway, user)
        assert manager.last_transition_id == 0
        assert manager.transitions == 1
        assert manager.pending_transitions == %{}
      end
    end

    test "a member alone in a call has no key, and says it is not ready" do
      gateway = Gateway.connect(Gateway.new(), @alice)

      refute ready?(gateway, @alice)
      assert {:error, :not_ready} = Gateway.encrypt(gateway, @alice, @opus)
    end

    test "a frame is encrypted for the group, not readable as someone else's" do
      gateway = call([@alice, @bob, @carol])
      {:ok, encrypted} = Gateway.encrypt(gateway, @alice, @opus)

      assert {:ok, @opus} = Gateway.decrypt(gateway, @carol, @alice, encrypted)
      assert {:error, :decrypt_failed} = Gateway.decrypt(gateway, @carol, @bob, encrypted)
    end

    test "silence goes out as it is, as Discord sends it" do
      gateway = call([@alice, @bob])

      assert {:ok, @silence} = Gateway.encrypt(gateway, @alice, @silence)
      assert {:ok, @silence} = Gateway.decrypt(gateway, @bob, @alice, @silence)
    end
  end

  describe "a member joining a call under way" do
    setup do
      gateway = [@alice, @bob] |> call() |> Gateway.connect(@carol)

      # Both members answer the proposals; the gateway keeps one commit.
      {gateway, answers} = Gateway.propose(gateway, [@alice, @bob], add: [@carol])
      assert {_commit, welcome} = answers[@alice]
      assert is_binary(welcome)
      assert {_commit, _welcome} = answers[@bob]

      %{gateway: Gateway.announce(gateway, 5, answers[@alice], add: [@carol])}
    end

    test "everyone acknowledges the transition", %{gateway: gateway} do
      for user <- [@alice, @bob, @carol] do
        assert {:ready, 5} in Gateway.sent(gateway, user)
        assert Gateway.member(gateway, user).pending_transitions == %{5 => 1}
      end
    end

    test "the member whose commit lost the race follows the winner's", %{gateway: gateway} do
      # Bob had prepared a commit of his own for the same proposals.
      refute Enum.any?(Gateway.sent(gateway, @bob), &match?({:invalid, _}, &1))

      gateway = Gateway.execute(gateway, 5)
      assert_heard(gateway, @bob, @carol)
      assert_heard(gateway, @alice, @bob)
    end

    test "until the transition executes, members keep the key the others expect", %{
      gateway: gateway
    } do
      # Alice and Bob already hold the new epoch's keys, and go on with the old one.
      assert_heard(gateway, @alice, @bob)
      assert_heard(gateway, @bob, @alice)

      # The newcomer was never given the old key: it cannot read what is sent with it.
      {:ok, old_key_frame} = Gateway.encrypt(gateway, @alice, @opus)
      assert {:error, :decrypt_failed} = Gateway.decrypt(gateway, @carol, @alice, old_key_frame)
    end

    test "the newcomer has no key until the transition executes", %{gateway: gateway} do
      refute ready?(gateway, @carol)
      assert {:error, :not_ready} = Gateway.encrypt(gateway, @carol, @opus)

      gateway = Gateway.execute(gateway, 5)
      assert ready?(gateway, @carol)
    end

    test "once it executes, everyone hears everyone", %{gateway: gateway} do
      gateway = Gateway.execute(gateway, 5)

      for sender <- [@alice, @bob, @carol],
          receiver <- [@alice, @bob, @carol],
          sender != receiver do
        assert_heard(gateway, sender, receiver)
      end

      for user <- [@alice, @bob, @carol] do
        manager = Gateway.member(gateway, user)
        assert manager.last_transition_id == 5
        assert manager.pending_transitions == %{}
      end
    end

    test "a frame sent just before the switch is still read just after", %{gateway: gateway} do
      {:ok, old_key_frame} = Gateway.encrypt(gateway, @alice, @opus)
      gateway = Gateway.execute(gateway, 5)

      assert {:ok, @opus} = Gateway.decrypt(gateway, @bob, @alice, old_key_frame)
    end

    test "the transition is what tells a consumer DAVE is ready", %{gateway: gateway} do
      before = Gateway.member(gateway, @carol)
      after_ = gateway |> Gateway.execute(5) |> Gateway.member(@carol)

      assert Manager.transitioned_to_dave?(before, after_)
    end
  end

  describe "a member leaving" do
    test "the others go on, and the one who left is no longer heard" do
      gateway = call([@alice, @bob, @carol])
      {:ok, from_carol} = Gateway.encrypt(gateway, @carol, @opus)
      assert {:ok, @opus} = Gateway.decrypt(gateway, @alice, @carol, from_carol)

      gateway = Gateway.change(gateway, remove: [@carol], transition: 6)

      assert_heard(gateway, @alice, @bob)
      assert_heard(gateway, @bob, @alice)
      assert {:error, :decrypt_failed} = Gateway.decrypt(gateway, @alice, @carol, from_carol)
    end

    test "a seat that was left is taken by the next to join" do
      gateway = call([@alice, @bob, @carol])
      gateway = Gateway.change(gateway, remove: [@bob], transition: 6)

      dave = 1_000_000_000_000_004
      gateway = gateway |> Gateway.connect(dave) |> Gateway.change(add: [dave], transition: 7)

      assert_heard(gateway, dave, @alice)
      assert_heard(gateway, @carol, dave)
    end
  end

  describe "a session that is not in the group" do
    test "ignores a commit, with nothing to report" do
      gateway = [@alice, @bob] |> call() |> Gateway.connect(@carol)
      {gateway, answers} = Gateway.propose(gateway, [@alice], add: [@carol])
      {commit, _welcome} = answers[@alice]

      {gateway, replies} =
        Gateway.deliver(gateway, @carol, 29, %{"transition_id" => 5, "commit_bin" => commit})

      assert replies == []
      refute Gateway.member(gateway, @carol).reinitializing
    end
  end

  describe "a welcome that is refused" do
    setup do
      gateway = [@alice, @bob] |> Enum.reduce(Gateway.new(), &Gateway.connect(&2, &1))
      {gateway, answers} = Gateway.propose(gateway, [@alice], add: [@bob])
      gateway = Gateway.seat_creator(gateway, @alice)

      %{gateway: gateway, commit_welcome: answers[@alice]}
    end

    test "for holding a user the session was not told about", %{
      gateway: gateway,
      commit_welcome: {_commit, welcome}
    } do
      data = %{"transition_id" => 3, "welcome_bin" => welcome}
      {gateway, replies} = Gateway.deliver(gateway, @bob, 30, data, connected_clients: [])

      assert [%{op: 31, d: %{transition_id: 3}}, {:binary, <<26, _::binary>>}] = replies
      assert Gateway.member(gateway, @bob).reinitializing
      refute ready?(gateway, @bob)
    end

    test "is answered with a new key package, which gets the member in", %{
      gateway: gateway,
      commit_welcome: {_commit, welcome} = commit_welcome
    } do
      data = %{"transition_id" => 3, "welcome_bin" => welcome}
      {gateway, _replies} = Gateway.deliver(gateway, @bob, 30, data, connected_clients: [])

      # The commit was announced all the same: for the group Bob is in, at the seat after
      # Alice's. The gateway removes him and adds him again with the key package he just sent.
      gateway = Gateway.announce(gateway, 3, commit_welcome, to: [@alice])
      gateway = %{gateway | leaves: Map.put(gateway.leaves, @bob, 1)}

      gateway =
        Gateway.change(gateway, remove: [@bob], add: [@bob], committer: @alice, transition: 4)

      refute Gateway.member(gateway, @bob).reinitializing
      assert_heard(gateway, @alice, @bob)
      assert_heard(gateway, @bob, @alice)
    end

    test "the welcome meant for a key package since replaced is refused too", %{
      gateway: gateway,
      commit_welcome: {_commit, welcome}
    } do
      # Bob offers a new key package before the welcome for the first one reaches him.
      {gateway, [_key_package]} = Gateway.deliver(gateway, @bob, 24, %{"epoch" => 1})

      {_gateway, replies} =
        Gateway.deliver(gateway, @bob, 30, %{"transition_id" => 3, "welcome_bin" => welcome})

      assert [%{op: 31, d: %{transition_id: 3}}, {:binary, <<26, _::binary>>}] = replies
    end
  end

  describe "the clients the voice session knows to be connected" do
    setup do
      gateway = [@alice, @bob] |> Enum.reduce(Gateway.new(), &Gateway.connect(&2, &1))
      {gateway, answers} = Gateway.propose(gateway, [@alice], add: [@bob])
      {_commit, welcome} = answers[@alice]

      state = %EDA.Voice.Session{
        guild_id: "dave-group-test",
        channel_id: to_string(gateway.channel_id),
        dave_manager: Gateway.member(gateway, @bob)
      }

      %{
        state: state,
        welcome: %{"op" => 30, "d" => %{"transition_id" => 3, "welcome_bin" => welcome}}
      }
    end

    test "decide whether a welcome is accepted", %{state: state, welcome: welcome} do
      state = %{state | connected_clients: MapSet.new([to_string(@alice)])}

      assert {:reply, %{op: 23, d: %{transition_id: 3}}, state} =
               EDA.Voice.Event.handle(welcome, state)

      assert state.dave_manager.pending_transitions == %{3 => 1}
    end

    test "refuse it when the group holds someone else", %{state: state, welcome: welcome} do
      assert {:reply, %{op: 31, d: %{transition_id: 3}}, state} =
               EDA.Voice.Event.handle(welcome, state)

      assert state.dave_manager.reinitializing
    end
  end

  describe "a commit that is refused" do
    setup do
      %{gateway: call([@alice, @bob])}
    end

    test "is reported, and answered with a new key package", %{gateway: gateway} do
      {_gateway, replies} =
        Gateway.deliver(gateway, @bob, 29, %{"transition_id" => 9, "commit_bin" => "not a commit"})

      assert [%{op: 31, d: %{transition_id: 9}}, {:binary, <<26, _::binary>>}] = replies
    end

    test "leaves the member heard and hearing until it is added again", %{gateway: gateway} do
      {gateway, _replies} =
        Gateway.deliver(gateway, @bob, 29, %{"transition_id" => 9, "commit_bin" => "not a commit"})

      # Re-initialising keeps the keys: a song under way does not stop.
      assert Gateway.member(gateway, @bob).reinitializing
      assert ready?(gateway, @bob)
      assert_heard(gateway, @bob, @alice)
      assert_heard(gateway, @alice, @bob)

      gateway =
        Gateway.change(gateway, remove: [@bob], add: [@bob], committer: @alice, transition: 10)

      refute Gateway.member(gateway, @bob).reinitializing
      assert Gateway.member(gateway, @bob).last_transition_id == 10
      assert_heard(gateway, @bob, @alice)
      assert_heard(gateway, @alice, @bob)
    end

    test "while it waits to be added again, commits are ignored and a welcome it refuses starts another round",
         %{gateway: gateway} do
      {gateway, _replies} =
        Gateway.deliver(gateway, @bob, 29, %{"transition_id" => 9, "commit_bin" => "not a commit"})

      assert {gateway, []} =
               Gateway.deliver(gateway, @bob, 29, %{
                 "transition_id" => 10,
                 "commit_bin" => "not a commit"
               })

      {_gateway, replies} =
        Gateway.deliver(gateway, @bob, 30, %{
          "transition_id" => 11,
          "welcome_bin" => "not a welcome"
        })

      assert [%{op: 31, d: %{transition_id: 11}}, {:binary, <<26, _::binary>>}] = replies
    end

    test "a commit announced twice is refused the second time", %{gateway: gateway} do
      gateway = Gateway.connect(gateway, @carol)
      {gateway, answers} = Gateway.propose(gateway, [@alice, @bob], add: [@carol])
      gateway = Gateway.announce(gateway, 5, answers[@alice], add: [@carol])
      {commit, _welcome} = answers[@alice]

      {_gateway, replies} =
        Gateway.deliver(gateway, @bob, 29, %{"transition_id" => 6, "commit_bin" => commit})

      assert [%{op: 31, d: %{transition_id: 6}}, {:binary, <<26, _::binary>>}] = replies
    end
  end

  describe "a call downgraded to no encryption, then upgraded again" do
    setup do
      gateway = call([@alice, @bob])

      gateway =
        Enum.reduce([@alice, @bob], gateway, fn user, gateway ->
          data = %{"transition_id" => 7, "protocol_version" => 0}

          {gateway, [%{op: 23, d: %{transition_id: 7}}]} =
            Gateway.deliver(gateway, user, 21, data)

          gateway
        end)

      %{gateway: gateway}
    end

    test "while the downgrade is pending, both kinds of frame are accepted", %{gateway: gateway} do
      # Bob may switch first: his unencrypted frames are let through...
      assert {:ok, @opus} = Gateway.decrypt(gateway, @alice, @bob, @opus)
      # ...and what he still encrypts is read as before.
      assert_heard(gateway, @bob, @alice)
    end

    test "once it executes, media goes unencrypted and the session says it is ready", %{
      gateway: gateway
    } do
      gateway = Gateway.execute(gateway, 7)

      for user <- [@alice, @bob] do
        manager = Gateway.member(gateway, user)
        assert manager.downgraded
        assert manager.protocol_version == 0
        assert Manager.current_version(manager) == 0
        assert Manager.ready?(manager)
      end

      assert {:ok, @opus} = Gateway.encrypt(gateway, @alice, @opus)
      assert {:ok, @opus} = Gateway.decrypt(gateway, @bob, @alice, @opus)
    end

    test "an upgrade keeps media unencrypted until its transition executes", %{gateway: gateway} do
      gateway = Gateway.execute(gateway, 7)

      # A new group is announced: both sessions start over and offer a key package.
      gateway =
        Enum.reduce([@alice, @bob], gateway, fn user, gateway ->
          data = %{"epoch" => 1, "protocol_version" => 1}
          {gateway, [{:binary, <<26, _::binary>>}]} = Gateway.deliver(gateway, user, 24, data)
          gateway
        end)

      gateway = %{gateway | epoch: 0, leaves: %{}}
      {gateway, answers} = Gateway.propose(gateway, [@alice], add: [@bob])
      gateway = Gateway.seat_creator(gateway, @alice)
      gateway = Gateway.announce(gateway, 8, answers[@alice], add: [@bob])

      # The call has agreed on DAVE again, and the others have not switched yet.
      for user <- [@alice, @bob] do
        manager = Gateway.member(gateway, user)
        assert manager.protocol_version == 1
        assert Manager.current_version(manager) == 0
        assert {:ready, 8} in Gateway.sent(gateway, user)
      end

      assert {:ok, @opus} = Gateway.encrypt(gateway, @alice, @opus)
      assert {:ok, @opus} = Gateway.decrypt(gateway, @bob, @alice, @opus)

      before = Gateway.member(gateway, @alice)
      gateway = Gateway.execute(gateway, 8)

      assert Manager.transitioned_to_dave?(before, Gateway.member(gateway, @alice))
      refute Gateway.member(gateway, @alice).downgraded
      assert Manager.current_version(Gateway.member(gateway, @alice)) == 1
      assert_heard(gateway, @alice, @bob)
      assert_heard(gateway, @bob, @alice)

      # Bob may not have switched yet: his unencrypted frames are still let through.
      assert {:ok, @opus} = Gateway.decrypt(gateway, @alice, @bob, @opus)
    end

    # Passthrough left on after an upgrade would accept unencrypted frames for the rest of the
    # call. Seeing it end takes ten seconds of a real call, so what is checked is the order the
    # session is given: off, with that expiry. What the order does is checked under
    # "unencrypted frames".
    test "an upgrade that executes turns passthrough off, with ten seconds of grace", %{
      gateway: gateway
    } do
      gateway = Gateway.execute(gateway, 7)
      alice = Gateway.member(gateway, @alice)
      session = alice.mls_session

      {alice, _} =
        Manager.handle_mls_event(alice, 21, %{"transition_id" => 8, "protocol_version" => 1})

      # A process cannot trace itself: the transition executes in one the test watches.
      test = self()

      pid =
        spawn_link(fn ->
          receive do
            :execute ->
              send(
                test,
                {:executed, Manager.handle_mls_event(alice, 22, %{"transition_id" => 8})}
              )
          end
        end)

      :erlang.trace_pattern({EDA.Voice.Dave.Native, :set_passthrough_mode, 3}, true, [])
      :erlang.trace(pid, true, [:call])
      send(pid, :execute)

      assert_receive {:executed, {alice, []}}
      refute alice.downgraded

      assert_receive {:trace, ^pid, :call,
                      {EDA.Voice.Dave.Native, :set_passthrough_mode, [^session, false, 10]}}

      refute_received {:trace, ^pid, :call, {EDA.Voice.Dave.Native, :set_passthrough_mode, _}}
    end
  end

  describe "unencrypted frames" do
    setup do
      gateway = call([@alice, @bob])
      %{gateway: gateway, session: Gateway.member(gateway, @alice).mls_session}
    end

    test "are refused in a call that is encrypted", %{gateway: gateway} do
      assert {:error, :decrypt_failed} = Gateway.decrypt(gateway, @alice, @bob, @opus)
    end

    test "are accepted while passthrough is on, and refused once its expiry has passed", %{
      gateway: gateway,
      session: session
    } do
      alias EDA.Voice.Dave.Native

      assert :ok = Native.set_passthrough_mode(session, true, 0)
      assert {:ok, @opus} = Gateway.decrypt(gateway, @alice, @bob, @opus)

      assert :ok = Native.set_passthrough_mode(session, false, 0)
      assert {:error, :decrypt_failed} = Gateway.decrypt(gateway, @alice, @bob, @opus)
    end
  end

  describe "frames that stop decrypting" do
    test "after 36 in a row, the session reports its last transition and asks to be added again" do
      gateway = call([@alice, @bob])
      garbage = <<1, 2, 3, 4, 5, 6, 7, 8, 9, 0xFA, 0xFA>>
      assert {:error, :decrypt_failed} = Gateway.decrypt(gateway, @alice, @bob, garbage)

      {manager, replies} =
        Enum.reduce(1..37, {Gateway.member(gateway, @alice), []}, fn _, {manager, _replies} ->
          Manager.decrypt_failed(manager)
        end)

      assert [%{op: 31, d: %{transition_id: 0}}, {:binary, <<26, _::binary>>}] = replies
      assert manager.reinitializing
      assert manager.decrypt_failures == 0
      # Still heard meanwhile.
      assert Manager.ready?(manager)
    end
  end
end
