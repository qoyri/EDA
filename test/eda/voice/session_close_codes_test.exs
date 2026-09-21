defmodule EDA.Voice.SessionCloseCodesTest do
  @moduledoc """
  How the voice session reacts to the close codes Discord uses to refuse a connection.

  4017 matters since March 2026: Discord refuses voice without DAVE outside Stage channels,
  and it used to fall through to a generic "disconnected" log that said nothing about why.
  """

  # NOT async — the session notifies the global EDA.Voice process.
  use ExUnit.Case

  import ExUnit.CaptureLog

  alias EDA.Voice.Session

  defp state, do: %Session{guild_id: "g_close_codes"}

  defp log_4017 do
    capture_log(fn ->
      assert {:ok, new_state} =
               Session.handle_disconnect(
                 %{reason: {:remote, 4017, "E2EE/DAVE protocol required"}},
                 state()
               )

      refute new_state.ready
    end)
  end

  test "4017 explains that DAVE is required" do
    log = log_4017()

    assert log =~ "4017"
    assert log =~ "DAVE"
    assert log =~ "Not reconnecting"
  end

  test "4017 names dave: false when that is why DAVE was not offered" do
    previous = Application.get_env(:eda, :dave)
    Application.put_env(:eda, :dave, false)

    on_exit(fn ->
      if is_nil(previous),
        do: Application.delete_env(:eda, :dave),
        else: Application.put_env(:eda, :dave, previous)
    end)

    assert log_4017() =~ "config :eda, dave: false"
  end

  test "4017 is not retried — reconnecting would be refused the same way" do
    capture_log(fn ->
      result = Session.handle_disconnect(%{reason: {:remote, 4017, "x"}}, state())

      # WebSockex reconnects on {:reconnect, _}; {:ok, _} ends the connection.
      assert match?({:ok, _}, result)
    end)
  end

  test "another unexplained close still takes the generic path" do
    log =
      capture_log(fn ->
        assert {:ok, _} = Session.handle_disconnect(%{reason: {:remote, 4020, "bad"}}, state())
      end)

    refute log =~ "DAVE"
  end
end
