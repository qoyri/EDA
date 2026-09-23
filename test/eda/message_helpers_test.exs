defmodule EDA.MessageHelpersTest do
  @moduledoc """
  Reading a message: its link, what it mentions, the invites it carries, whether it is a system
  message or can be deleted, and its content with the mentions named.
  """

  # NOT async — clean_content/1 reads the shared role cache.
  use ExUnit.Case

  alias EDA.Message

  doctest EDA.Message, only: [url: 1, parse_link: 1, invites: 1, deletable?: 1]

  @guild "7714000000000000000"

  test "mentions?/2 of a user, a member, a role and everyone" do
    message =
      Message.from_raw(%{
        "mentions" => [%{"id" => "1"}],
        "mention_roles" => ["9"],
        "mention_everyone" => true
      })

    assert Message.mentions?(message, %EDA.User{id: "1"})
    assert Message.mentions?(message, %EDA.Member{user: %EDA.User{id: "1"}})
    refute Message.mentions?(message, %EDA.User{id: "2"})
    assert Message.mentions?(message, %EDA.Role{id: "9"})
    assert Message.mentions?(message, :everyone)
  end

  test "system?/1 and webhook?/1" do
    refute Message.system?(%Message{type: :reply})
    assert Message.system?(%Message{type: :user_join})
    assert Message.webhook?(%Message{webhook_id: "4"})
  end

  test "clean_content/1 names users by their nickname, roles and channels" do
    EDA.Cache.Role.create(@guild, %{"id" => "7714000000000000009", "name" => "mods"})

    message =
      Message.from_raw(%{
        "guild_id" => @guild,
        "content" => "hi <@1> and <@!2>, ping <@&7714000000000000009> in <#5>, not <@3>",
        "mentions" => [
          %{"id" => "1", "username" => "ann", "member" => %{"nick" => "Annie"}},
          %{"id" => "2", "username" => "bob", "global_name" => "Bobby"}
        ],
        "mention_channels" => [%{"id" => "5", "name" => "general", "type" => 0}]
      })

    assert Message.clean_content(message) ==
             "hi @Annie and @Bobby, ping @mods in #general, not <@3>"
  end

  test "a message activity can be a stream request" do
    assert %EDA.Message.Activity{type: :stream_request} =
             EDA.Message.Activity.from_raw(%{"type" => 6})
  end
end
