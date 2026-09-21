defmodule EDA.Voice.DaveAvailabilityTest do
  @moduledoc """
  DAVE is only advertised to Discord when EDA can actually speak it.

  Advertising `max_dave_protocol_version` commits the voice session to MLS, so doing it
  without the NIF would leave Discord expecting end-to-end encrypted media that EDA cannot
  produce. The NIF-absent branch cannot be exercised here — EDA's own environment always has
  Rustler — so it is covered by the consumer-project job in CI, which compiles EDA without
  `:rustler` and checks that `dave: true` degrades instead of crashing.
  """

  # NOT async — mutates the :dave application env and the cached bot user.
  use ExUnit.Case

  import ExUnit.CaptureLog

  @hello %{"op" => 8, "d" => %{"heartbeat_interval" => 41_250}}
  @state %{
    guild_id: "1",
    session_id: "s",
    token: "tok",
    heartbeat_interval: nil,
    heartbeat_ref: nil
  }

  setup do
    EDA.Voice.Event.reset_dave_warnings()
    on_exit(&EDA.Voice.Event.reset_dave_warnings/0)
    previous_dave = Application.get_env(:eda, :dave)
    previous_me = :persistent_term.get(:eda_current_user_raw, nil)
    EDA.Cache.put_me(%{"id" => "999", "username" => "eda"})

    on_exit(fn ->
      if is_nil(previous_dave),
        do: Application.delete_env(:eda, :dave),
        else: Application.put_env(:eda, :dave, previous_dave)

      if previous_me,
        do: EDA.Cache.put_me(previous_me),
        else:
          :persistent_term.erase(:eda_current_user) &&
            :persistent_term.erase(:eda_current_user_raw)
    end)

    :ok
  end

  defp advertised_version do
    {:reply, identify, _state} = EDA.Voice.Event.handle(@hello, @state)
    identify.d[:max_dave_protocol_version]
  end

  test "the NIF is loaded in EDA's own environment" do
    # If this fails, the loader stopped emitting `use Rustler` even where Rustler exists.
    assert EDA.Voice.Dave.Native.available?()
  end

  test "dave: true with the NIF available advertises protocol version 1" do
    Application.put_env(:eda, :dave, true)
    assert advertised_version() == 1
  end

  test "dave: false advertises nothing" do
    Application.put_env(:eda, :dave, false)
    capture_log(fn -> assert advertised_version() == nil end)
  end

  test "an unset :dave advertises nothing" do
    Application.delete_env(:eda, :dave)
    capture_log(fn -> assert advertised_version() == nil end)
  end

  describe "connecting without DAVE is announced before Discord refuses it" do
    test "the default configuration warns, naming 4017 and where to read more" do
      # Discord refuses voice without DAVE outside Stage channels. With :dave unset, nothing
      # used to be said until the connection was refused.
      Application.delete_env(:eda, :dave)

      log = capture_log(fn -> advertised_version() end)

      assert log =~ "without DAVE"
      assert log =~ "4017"
      assert log =~ "Stage"
      assert log =~ "https://hexdocs.pm/eda/readme.html#voice"
    end

    test "it warns once per VM, not on every voice connection" do
      Application.put_env(:eda, :dave, false)

      first = capture_log(fn -> advertised_version() end)
      second = capture_log(fn -> advertised_version() end)

      assert first =~ "without DAVE"
      refute second =~ "without DAVE"
    end

    test "with DAVE enabled and the NIF loaded, nothing is said" do
      Application.put_env(:eda, :dave, true)

      log = capture_log(fn -> assert advertised_version() == 1 end)

      refute log =~ "DAVE"
    end
  end
end
