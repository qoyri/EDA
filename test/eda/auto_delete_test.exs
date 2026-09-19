defmodule EDA.AutoDeleteTest do
  use ExUnit.Case

  alias EDA.AutoDelete

  describe "schedule/3" do
    test "nil delay is a no-op" do
      assert :ok = AutoDelete.schedule("ch1", "msg1", nil)
    end

    test "schedules deletion (GenServer accepts the cast)" do
      assert :ok = AutoDelete.schedule("ch1", "msg1", 60_000)
    end

    # A zero delay fires almost immediately and spawns a Task that performs a REAL
    # HTTP DELETE against whatever `:base_url` is configured when it runs. Without a
    # Bypass of its own — and without waiting for the request — that DELETE escapes
    # this test and lands on the next test's Bypass, failing an unrelated test with
    # "Bypass got an HTTP request but wasn't expecting one".
    test "zero delay actually issues the delete, and it is consumed here" do
      bypass = Bypass.open()
      Application.put_env(:eda, :base_url, "http://localhost:#{bypass.port}")
      Application.put_env(:eda, :token, "test-token")
      on_exit(fn -> Application.delete_env(:eda, :base_url) end)

      test_pid = self()

      Bypass.expect(bypass, "DELETE", "/channels/ch_zero/messages/msg_zero", fn conn ->
        send(test_pid, :deletion_sent)
        Plug.Conn.resp(conn, 204, "")
      end)

      assert :ok = AutoDelete.schedule("ch_zero", "msg_zero", 0)

      # Waiting here is what keeps the request inside this test.
      assert_receive :deletion_sent, 2_000
    end
  end
end
