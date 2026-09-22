defmodule EDA.Voice.Dave.ManagerTest do
  use ExUnit.Case, async: true

  alias EDA.Voice.Dave.Manager

  describe "new/3" do
    test "version 0 creates a passthrough manager" do
      manager = Manager.new(0, 12_345, 67_890)
      assert manager.protocol_version == 0
      assert manager.mls_session == nil
    end

    test "version > 0 creates an active manager with MLS session" do
      manager = Manager.new(1, 12_345, 67_890)
      assert manager.protocol_version == 1
      assert is_reference(manager.mls_session)
    end
  end

  describe "active?/1" do
    test "returns false for passthrough manager" do
      manager = Manager.new(0, 12_345, 67_890)
      refute Manager.active?(manager)
    end

    test "returns true for active manager" do
      manager = Manager.new(1, 12_345, 67_890)
      assert Manager.active?(manager)
    end
  end

  describe "encrypt_frame/2 passthrough" do
    test "returns frame unchanged when version is 0" do
      manager = Manager.new(0, 12_345, 67_890)
      frame = <<0xFC, 1, 2, 3, 4, 5>>
      assert {:ok, ^frame, _manager} = Manager.encrypt_frame(manager, frame)
    end
  end

  describe "encrypt_frame/2 active DAVE session" do
    test "returns an error when DAVE is enabled but no MLS session is available" do
      manager = %Manager{protocol_version: 1, mls_session: nil}
      frame = <<0xFC, 1, 2, 3, 4, 5>>

      assert {:error, :session_unavailable, _manager} = Manager.encrypt_frame(manager, frame)
    end
  end

  describe "decrypt_frame/3 passthrough" do
    test "returns frame unchanged when version is 0" do
      manager = Manager.new(0, 12_345, 67_890)
      frame = <<0xFC, 1, 2, 3, 4, 5>>
      assert {:ok, ^frame, _manager} = Manager.decrypt_frame(manager, frame, 99_999)
    end
  end

  describe "handle_mls_event/3" do
    test "OP 24 (PREPARE_EPOCH) epoch=1 re-initialises and sends a key package" do
      manager = Manager.new(1, 12_345, 67_890)

      {manager, replies} =
        Manager.handle_mls_event(manager, 24, %{"epoch" => 1, "protocol_version" => 1})

      assert [{:binary, <<26, _::binary>>}] = replies
      assert manager.protocol_version == 1
    end

    test "OP 24 (PREPARE_EPOCH) epoch=1 at protocol 0 resets without a key package" do
      manager = Manager.new(1, 12_345, 67_890)

      {manager, replies} =
        Manager.handle_mls_event(manager, 24, %{"epoch" => 1, "protocol_version" => 0})

      assert replies == []
      assert Manager.current_version(manager) == 0
    end

    test "OP 24 (PREPARE_EPOCH) epoch!=1 returns no replies" do
      manager = Manager.new(1, 12_345, 67_890)
      {_manager, replies} = Manager.handle_mls_event(manager, 24, %{"epoch" => 2})
      assert replies == []
    end

    test "OP 31 (INVALID_COMMIT) returns no replies" do
      manager = Manager.new(1, 12_345, 67_890)
      {_manager, replies} = Manager.handle_mls_event(manager, 31, %{"reason" => "test"})
      assert replies == []
    end

    test "unhandled opcode returns no replies" do
      manager = Manager.new(0, 12_345, 67_890)
      {_manager, replies} = Manager.handle_mls_event(manager, 99, %{})
      assert replies == []
    end
  end

  describe "transitions" do
    setup do
      %{manager: Manager.new(1, 12_345, 67_890)}
    end

    test "transition 0 executes at once and is not acknowledged", %{manager: manager} do
      {manager, replies} =
        Manager.handle_mls_event(manager, 21, %{"transition_id" => 0, "protocol_version" => 1})

      assert replies == []
      assert manager.pending_transitions == %{}
      assert manager.last_transition_id == 0
      assert manager.transitions == 1
    end

    test "any other transition is acknowledged and waits for OP 22", %{manager: manager} do
      {manager, replies} =
        Manager.handle_mls_event(manager, 21, %{"transition_id" => 4, "protocol_version" => 1})

      assert [%{op: 23, d: %{transition_id: 4}}] = replies
      assert manager.pending_transitions == %{4 => 1}
      assert manager.transitions == 0

      {manager, []} = Manager.handle_mls_event(manager, 22, %{"transition_id" => 4})
      assert manager.pending_transitions == %{}
      assert manager.last_transition_id == 4
      assert manager.transitions == 1
    end

    test "OP 22 for a transition that is not pending changes nothing", %{manager: manager} do
      assert {^manager, []} = Manager.handle_mls_event(manager, 22, %{"transition_id" => 9})
    end

    test "a downgrade to protocol 0 is acknowledged, then turns encryption off", %{
      manager: manager
    } do
      # The playback process holds a copy taken when the connection became ready.
      playback_copy = manager
      frame = <<1, 2, 3, 4, 5>>

      {manager, replies} =
        Manager.handle_mls_event(manager, 21, %{"transition_id" => 2, "protocol_version" => 0})

      assert [%{op: 23, d: %{transition_id: 2}}] = replies
      assert Manager.current_version(manager) == 1

      {downgraded, []} = Manager.handle_mls_event(manager, 22, %{"transition_id" => 2})

      assert downgraded.downgraded
      assert Manager.current_version(downgraded) == 0
      refute Manager.transitioned_to_dave?(manager, downgraded)

      # Discord now expects unencrypted media, and the copy sees the transition too.
      assert {:ok, ^frame, _} = Manager.encrypt_frame(downgraded, frame)
      assert {:ok, ^frame, _} = Manager.encrypt_frame(playback_copy, frame)
      assert {:ok, ^frame, _} = Manager.decrypt_frame(downgraded, frame, 42)
    end

    test "an upgrade after a downgrade restores DAVE", %{manager: manager} do
      {manager, _} =
        Manager.handle_mls_event(manager, 21, %{"transition_id" => 2, "protocol_version" => 0})

      {downgraded, []} = Manager.handle_mls_event(manager, 22, %{"transition_id" => 2})

      {manager, _} =
        Manager.handle_mls_event(downgraded, 21, %{"transition_id" => 3, "protocol_version" => 1})

      {upgraded, []} = Manager.handle_mls_event(manager, 22, %{"transition_id" => 3})

      refute upgraded.downgraded
      assert Manager.current_version(upgraded) == 1
      assert Manager.transitioned_to_dave?(downgraded, upgraded)
    end
  end

  describe "recovery from a refused commit or welcome" do
    setup do
      %{manager: Manager.new(1, 12_345, 67_890)}
    end

    test "a refused commit reports the transition and offers a new key package", %{
      manager: manager
    } do
      {manager, replies} =
        Manager.handle_mls_event(manager, 29, %{"transition_id" => 3, "commit_bin" => "garbage"})

      assert [%{op: 31, d: %{transition_id: 3}}, {:binary, <<26, _::binary>>}] = replies
      assert manager.reinitializing
    end

    test "a refused welcome reports the transition and offers a new key package", %{
      manager: manager
    } do
      {manager, replies} =
        Manager.handle_mls_event(manager, 30, %{"transition_id" => 5, "welcome_bin" => "garbage"})

      assert [%{op: 31, d: %{transition_id: 5}}, {:binary, <<26, _::binary>>}] = replies
      assert manager.reinitializing
    end

    test "recovers once, not once per failure", %{manager: manager} do
      {manager, [_ | _]} =
        Manager.handle_mls_event(manager, 30, %{"transition_id" => 5, "welcome_bin" => "garbage"})

      assert {_, []} =
               Manager.handle_mls_event(manager, 29, %{
                 "transition_id" => 6,
                 "commit_bin" => "garbage"
               })
    end

    test "an executed transition ends the recovery", %{manager: manager} do
      {manager, _} =
        Manager.handle_mls_event(manager, 30, %{"transition_id" => 5, "welcome_bin" => "garbage"})

      {manager, []} =
        Manager.handle_mls_event(manager, 21, %{"transition_id" => 0, "protocol_version" => 1})

      refute manager.reinitializing
    end
  end

  describe "decrypt_frame/3" do
    test "passes Opus silence frames through, as Discord sends them unencrypted" do
      manager = Manager.new(1, 12_345, 67_890)

      assert {:ok, <<0xF8, 0xFF, 0xFE>>, _} =
               Manager.decrypt_frame(manager, <<0xF8, 0xFF, 0xFE>>, 42)
    end

    test "a frame that does not decrypt is an error, not let through as passthrough" do
      manager = Manager.new(1, 12_345, 67_890)
      garbage = <<1, 2, 3, 4, 5, 6, 7, 8, 9, 10>>

      # No decryptor for user 42, so no passthrough either.
      assert {:error, :decrypt_failed} = Manager.decrypt_frame(manager, garbage, 42)
    end

    test "a frame that decrypts ends a run of failures" do
      manager = %{Manager.new(1, 12_345, 67_890) | decrypt_failures: 12}

      assert {:ok, _, %Manager{decrypt_failures: 0}} =
               Manager.decrypt_frame(manager, <<0xF8, 0xFF, 0xFE>>, 42)
    end
  end

  describe "decrypt_failed/1" do
    setup do
      # Joined through transition 0, as after a welcome: a transition to report exists.
      {manager, []} =
        Manager.handle_mls_event(Manager.new(1, 12_345, 67_890), 21, %{
          "transition_id" => 0,
          "protocol_version" => 1
        })

      %{manager: manager}
    end

    defp fail(manager, times) do
      Enum.reduce(1..times, {manager, []}, fn _, {m, _} -> Manager.decrypt_failed(m) end)
    end

    test "tolerates 36 failures in a row", %{manager: manager} do
      assert {%Manager{decrypt_failures: 36, reinitializing: false}, []} = fail(manager, 36)
    end

    test "the 37th reports the last transition and offers a new key package", %{manager: manager} do
      {manager, replies} = fail(manager, 37)

      assert [%{op: 31, d: %{transition_id: 0}}, {:binary, <<26, _::binary>>}] = replies
      assert manager.reinitializing
      assert manager.decrypt_failures == 0
    end

    test "failures while re-initialising are not counted", %{manager: manager} do
      {manager, [_ | _]} = fail(manager, 37)
      assert {%Manager{decrypt_failures: 0}, []} = fail(manager, 100)
    end

    test "failures while a transition is pending are not counted", %{manager: manager} do
      {manager, _} =
        Manager.handle_mls_event(manager, 21, %{"transition_id" => 4, "protocol_version" => 1})

      assert {%Manager{decrypt_failures: 0}, []} = fail(manager, 100)
    end

    test "without a transition to report, keeps counting and sends nothing" do
      manager = Manager.new(1, 12_345, 67_890)
      assert manager.last_transition_id == nil
      assert {%Manager{decrypt_failures: 50}, []} = fail(manager, 50)
    end
  end
end
