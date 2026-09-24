defmodule Mix.Tasks.Eda.DoctorTest do
  # NOT async — the task test swaps the global Mix shell.
  use ExUnit.Case

  alias Mix.Tasks.Eda.Doctor

  @fields MapSet.new(~w(nick type author status joined_at content))

  defp scan(source), do: Doctor.scan(source, "lib/bot.ex", @fields)
  defp lines(source), do: source |> scan() |> Enum.map(&elem(&1, 1))

  test "Map functions with a string key that is a struct field" do
    source = """
    nick = Map.get(member, "nick")
    Map.has_key?(msg, "content")
    Map.get(payload, "unrelated_key")
    """

    assert [{_, 1, "nick = Map.get(member, \"nick\")", message}, {_, 2, _, _}] = scan(source)
    assert message =~ "x.nick"
  end

  test "string-keyed patterns on struct fields" do
    assert lines(~s|def handle_event({:MESSAGE_CREATE, %{"author" => a}}), do: a|) == [1]
    assert lines(~s|%{"op" => 10} = payload|) == []
  end

  test "a map being built is not a pattern" do
    assert lines(~s|EDA.API.Thread.start(id, %{name: "t", type: 11})|) == []
    assert lines(~s|send_json(%{"role" => "user", "content" => text})|) == []
    assert lines(~s|{:ok, %{"content" => c}} ->|) == [1]
  end

  test "an enumeration compared to an integer" do
    source = """
    if channel.type == 0, do: :text
    removal? = entry.action_type in [20, 22]
    %EDA.Channel{type: 2} = channel
    x["type"] != 4
    if channel.type == :guild_text, do: :text
    position == 0
    """

    assert lines(source) == [1, 2, 3, 4]
  end

  test "a presence status compared to a string" do
    assert lines(~s|if presence.status == "online", do: :up|) == [1]
    assert lines(~s|if presence.status == :online, do: :up|) == []
  end

  test "DateTime.from_iso8601 on a date EDA parses" do
    assert lines("{:ok, at, _} = DateTime.from_iso8601(member.joined_at)") == [1]
    assert lines(~s|DateTime.from_iso8601("2026-01-01T00:00:00Z")|) == []
  end

  test "comments and marked lines are skipped" do
    source = """
    # channel.type == 0 was the old way
    Map.get(raw, "nick") # eda-doctor: ignore
    """

    assert scan(source) == []
  end

  test "the task reports and --strict fails" do
    dir = Path.join(System.tmp_dir!(), "eda_doctor_#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    on_exit(fn -> File.rm_rf!(dir) end)
    File.write!(Path.join(dir, "bot.ex"), "if channel.type == 0, do: :text\n")

    Mix.shell(Mix.Shell.Process)
    on_exit(fn -> Mix.shell(Mix.Shell.IO) end)

    Doctor.run([dir])
    assert_received {:mix_shell, :info, [_ | _] = report}
    assert IO.iodata_to_binary(report) =~ "bot.ex:1"

    assert catch_exit(Doctor.run(["--strict", dir])) == {:shutdown, 1}
  end
end
