defmodule EDA.Voice.Dave.NativeTest do
  use ExUnit.Case, async: true

  alias EDA.Voice.Dave.Native

  defp create_session do
    # NIF new_session returns Result<ResourceArc, Atom> which Rustler
    # encodes as the resource ref directly on success
    case Native.new_session(1, 12_345, 67_890) do
      {:ok, ref} -> ref
      ref when is_reference(ref) -> ref
    end
  end

  describe "new_session/3" do
    test "creates a valid session" do
      ref = create_session()
      assert is_reference(ref)
    end
  end

  describe "create_key_package/1" do
    test "returns a non-empty binary" do
      ref = create_session()
      result = Native.create_key_package(ref)
      # Unwrap the Result + tuple encoding: {:ok, binary} or {:ok, {:ok, binary}}
      key_package =
        case result do
          {:ok, {:ok, bin}} -> bin
          {:ok, bin} when is_binary(bin) -> bin
        end

      assert is_binary(key_package)
      assert byte_size(key_package) > 0
    end
  end

  describe "get_epoch/1" do
    test "returns 0 for a fresh session" do
      ref = create_session()

      epoch =
        case Native.get_epoch(ref) do
          {:ok, n} -> n
          n when is_integer(n) -> n
        end

      assert epoch == 0
    end
  end

  describe "ready?/1" do
    test "returns false for a fresh session" do
      ref = create_session()

      ready =
        case Native.ready?(ref) do
          {:ok, val} -> val
          val when is_boolean(val) -> val
        end

      refute ready
    end
  end

  describe "set_passthrough_mode/3" do
    test "sets passthrough with a transition expiry" do
      ref = create_session()
      assert :ok = Native.set_passthrough_mode(ref, true, 24)
      assert :ok = Native.set_passthrough_mode(ref, false, 10)
    end
  end

  describe "can_encrypt?/1" do
    test "is false for a session that is in no group" do
      assert {:ok, false} = Native.can_encrypt?(create_session())
    end
  end

  describe "commits and welcomes" do
    test "a welcome before the external sender is known says so" do
      assert {:error, :no_external_sender} =
               Native.process_welcome(create_session(), "garbage", [])
    end

    test "a commit that reaches a session in no group is ignored" do
      assert :ignored = Native.process_commit(create_session(), "garbage")
    end
  end

  describe "transitions" do
    test "a prepared transition executes once" do
      ref = create_session()

      assert :ok = Native.prepare_transition(ref, 4, 1)
      assert :ok = Native.execute_transition(ref, 4)
      assert :not_pending = Native.execute_transition(ref, 4)
    end

    test "a transition that was not prepared does not execute" do
      assert :not_pending = Native.execute_transition(create_session(), 9)
    end

    test "transition 0 executes when it is prepared" do
      ref = create_session()

      assert :ok = Native.prepare_transition(ref, 0, 1)
      assert :not_pending = Native.execute_transition(ref, 0)
    end

    test "re-initialising forgets the transitions that were prepared" do
      ref = create_session()

      assert :ok = Native.prepare_transition(ref, 4, 1)
      assert :ok = Native.reinit(ref, 1, 12_345, 67_890)
      assert :not_pending = Native.execute_transition(ref, 4)
    end
  end

  describe "available?/0" do
    test "returns true when NIF is loaded" do
      assert Native.available?()
    end
  end
end
