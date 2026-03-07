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
    test "OP 21 (PREPARE_TRANSITION) returns no replies" do
      manager = Manager.new(1, 12_345, 67_890)
      {_manager, replies} = Manager.handle_mls_event(manager, 21, %{"protocol_version" => 1})
      assert replies == []
    end

    test "OP 24 (PREPARE_EPOCH) epoch=1 resets and sends key package" do
      manager = Manager.new(1, 12_345, 67_890)
      {_manager, replies} = Manager.handle_mls_event(manager, 24, %{"epoch" => 1})
      assert [{:binary, <<26, _::binary>>}] = replies
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

    test "OP 22 (EXECUTE_TRANSITION) clears pending state" do
      manager = Manager.new(1, 12_345, 67_890)
      manager = %{manager | pending_epoch: 5, transition_id: 1}
      {manager, replies} = Manager.handle_mls_event(manager, 22, %{})
      assert manager.pending_epoch == nil
      assert manager.transition_id == nil
      assert replies == []
    end

    test "unhandled opcode returns no replies" do
      manager = Manager.new(0, 12_345, 67_890)
      {_manager, replies} = Manager.handle_mls_event(manager, 99, %{})
      assert replies == []
    end
  end
end
