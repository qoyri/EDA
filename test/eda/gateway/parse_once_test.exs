defmodule EDA.Gateway.ParseOnceTest do
  @moduledoc """
  With a consumer, an event is parsed once and the caches take the struct; without one, they
  parse the payload. Both must leave the caches the same.
  """

  # NOT async — the caches and the consumer setting are global.
  use ExUnit.Case

  defmodule Noop do
    def handle_event(_), do: :ok
  end

  setup do
    previous = Application.get_env(:eda, :consumer)
    on_exit(fn -> Application.put_env(:eda, :consumer, previous) end)
    :ok
  end

  defp guild_create(g) do
    %{
      "id" => g,
      "name" => "P",
      "owner_id" => "1",
      "roles" => [%{"id" => g, "name" => "@everyone", "position" => 0}],
      "channels" => [%{"id" => g <> "1", "type" => 0, "name" => "general"}],
      "threads" => [
        %{"id" => g <> "2", "type" => 11, "parent_id" => g <> "1", "thread_metadata" => %{}}
      ],
      "members" => [%{"user" => %{"id" => g <> "3", "username" => "ann"}, "roles" => [g]}],
      "voice_states" => [%{"user_id" => g <> "3", "channel_id" => g <> "1"}],
      "presences" => [%{"user" => %{"id" => g <> "3"}, "status" => "idle"}]
    }
  end

  defp snapshot(g) do
    %{
      guild: EDA.Cache.get_guild(g),
      channels: EDA.Cache.channels_for_guild(g) |> Enum.sort_by(& &1.id),
      members: EDA.Cache.members(g),
      roles: EDA.Cache.roles(g),
      voice: EDA.Cache.voice_states(g),
      presences: EDA.Cache.presences(g),
      user: EDA.Cache.get_user(g <> "3")
    }
  end

  test "GUILD_CREATE leaves the same caches whether the event was parsed for a consumer or not" do
    Application.put_env(:eda, :consumer, nil)
    EDA.Gateway.Events.dispatch("GUILD_CREATE", guild_create("7719000000000000000"))
    without = snapshot("7719000000000000000")

    Application.put_env(:eda, :consumer, Noop)
    EDA.Gateway.Events.dispatch("GUILD_CREATE", guild_create("7719000000000000100"))
    with_consumer = snapshot("7719000000000000100")

    rename = fn term ->
      term
      |> :erlang.term_to_binary()
      |> :binary.replace("7719000000000000100", "7719000000000000000", [:global])
      |> :erlang.binary_to_term()
    end

    assert rename.(with_consumer) == without
    assert %EDA.Guild{members: nil, channels: nil, roles: nil} = with_consumer.guild
    assert [%EDA.Channel{}, %EDA.Channel{thread: %EDA.Channel.Thread{}}] = with_consumer.channels
  end

  test "MESSAGE_CREATE caches its author and member from the struct" do
    Application.put_env(:eda, :consumer, Noop)
    g = "7719000000000000200"

    EDA.Gateway.Events.dispatch("MESSAGE_CREATE", %{
      "id" => "1",
      "guild_id" => g,
      "channel_id" => "2",
      "author" => %{"id" => g <> "9", "username" => "bob"},
      "member" => %{"nick" => "Bobby", "roles" => []}
    })

    assert %EDA.User{username: "bob"} = EDA.Cache.get_user(g <> "9")

    assert %EDA.Member{nick: "Bobby", guild_id: ^g, user: %EDA.User{username: "bob"}} =
             EDA.Cache.get_member(g, g <> "9")
  end
end
