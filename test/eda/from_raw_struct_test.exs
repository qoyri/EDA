defmodule EDA.FromRawStructTest do
  @moduledoc """
  `from_raw/1` on a struct it already returned gives it back unchanged: parsing it again used to
  lose what it held in nested structs.
  """

  use ExUnit.Case, async: true

  test "a message keeps its author" do
    msg = EDA.Message.from_raw(%{"id" => "1", "author" => %{"id" => "2", "username" => "a"}})
    assert EDA.Message.from_raw(msg) == msg
    assert %EDA.User{id: "2"} = msg.author
  end

  test "a member keeps its user" do
    member = EDA.Member.from_raw(%{"user" => %{"id" => "3", "username" => "b"}, "roles" => []})
    assert EDA.Member.from_raw(member) == member
  end

  test "a voice channel keeps its settings" do
    channel = EDA.Channel.from_raw(%{"id" => "4", "type" => 2, "bitrate" => 64_000})
    assert EDA.Channel.from_raw(channel) == channel
  end
end
