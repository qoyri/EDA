defmodule EDA.OAuth2Test do
  use ExUnit.Case

  alias EDA.OAuth2

  describe "invite_url/1" do
    test "generates URL with explicit client_id" do
      url = OAuth2.invite_url(client_id: "123456")

      assert url =~ "https://discord.com/oauth2/authorize?"
      assert url =~ "client_id=123456"
      assert url =~ "scope=bot+applications.commands"
      assert url =~ "permissions=0"
    end

    test "accepts permission atoms" do
      url =
        OAuth2.invite_url(client_id: "123", permissions: [:send_messages, :read_message_history])

      permissions = EDA.Permission.to_bitset([:send_messages, :read_message_history])
      assert url =~ "permissions=#{permissions}"
    end

    test "accepts integer permissions" do
      url = OAuth2.invite_url(client_id: "123", permissions: 8)
      assert url =~ "permissions=8"
    end

    test "custom scopes" do
      url = OAuth2.invite_url(client_id: "123", scopes: ["bot"])
      assert url =~ "scope=bot"
      refute url =~ "applications.commands"
    end

    test "includes guild_id when provided" do
      url = OAuth2.invite_url(client_id: "123", guild_id: "999")
      assert url =~ "guild_id=999"
    end

    test "omits guild_id when not provided" do
      url = OAuth2.invite_url(client_id: "123")
      refute url =~ "guild_id"
    end

    test "includes disable_guild_select when true" do
      url = OAuth2.invite_url(client_id: "123", disable_guild_select: true)
      assert url =~ "disable_guild_select=true"
    end

    test "omits disable_guild_select when false" do
      url = OAuth2.invite_url(client_id: "123", disable_guild_select: false)
      refute url =~ "disable_guild_select"
    end
  end
end
