defmodule EDA.Cache.UserRestOnlyTest do
  @moduledoc """
  The gateway never sends a user's banner or accent colour. A user seen on the gateway must not
  clear what a REST fetch put in the cache; a REST result replaces the entry whole.
  """

  # NOT async — the caches and the :consumer env are global.
  use ExUnit.Case

  defmodule Noop do
    def handle_event(_), do: :ok
  end

  @guild "7719000000000000001"

  setup do
    previous = Application.get_env(:eda, :consumer)
    on_exit(fn -> Application.put_env(:eda, :consumer, previous) end)
    :ok
  end

  defp rest_user(id),
    do: %{"id" => id, "username" => "before", "banner" => "b4nn3r", "accent_color" => 16_711_680}

  defp message(id, author_id),
    do: %{
      "id" => id,
      "channel_id" => "7719000000000000002",
      "guild_id" => @guild,
      "content" => "hi",
      "author" => %{"id" => author_id, "username" => "after"}
    }

  for {label, consumer, id} <- [
        {"with a consumer", Noop, "7719000000000000010"},
        {"without a consumer", nil, "7719000000000000020"}
      ] do
    test "a message #{label} keeps the banner a REST fetch cached" do
      Application.put_env(:eda, :consumer, unquote(consumer))
      id = unquote(id)

      EDA.Cache.User.create(rest_user(id))
      EDA.Gateway.Events.dispatch("MESSAGE_CREATE", message("7719000000000000003", id))

      user = EDA.Cache.User.get(id)
      assert user.username == "after"
      assert user.banner == "b4nn3r"
      assert user.accent_color == 16_711_680
    end
  end

  test "a REST result replaces the entry, banner included" do
    id = "7719000000000000100"
    EDA.Cache.User.create(rest_user(id))
    EDA.Cache.User.create(%{"id" => id, "username" => "rest", "banner" => nil})

    assert %EDA.User{username: "rest", banner: nil, accent_color: nil} = EDA.Cache.User.get(id)
  end

  test "merge/1 caches a user it has not seen as it is" do
    id = "7719000000000000200"
    assert %EDA.User{banner: nil} = EDA.Cache.User.merge(%{"id" => id, "username" => "new"})
    assert %EDA.User{username: "new"} = EDA.Cache.User.get(id)
  end
end
