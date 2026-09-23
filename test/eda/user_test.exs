defmodule EDA.UserTest do
  use ExUnit.Case

  alias EDA.User

  defp sample_user do
    User.from_raw(%{
      "id" => "123",
      "username" => "alice",
      "avatar" => "abc123",
      "discriminator" => "0",
      "public_flags" => 64,
      "bot" => false,
      "global_name" => "Alice"
    })
  end

  describe "from_raw/1" do
    test "parses all fields" do
      user = sample_user()
      assert %User{} = user
      assert user.id == "123"
      assert user.username == "alice"
      assert user.avatar == "abc123"
      assert user.discriminator == "0"
      assert user.public_flags == 64
      assert user.bot == false
      assert user.global_name == "Alice"
    end

    test "handles partial data" do
      user = User.from_raw(%{"id" => "1"})
      assert user.id == "1"
      assert user.username == nil
    end
  end

  describe "mention/1" do
    test "returns mention string" do
      assert User.mention(sample_user()) == "<@123>"
    end
  end

  describe "avatar_url/1" do
    test "returns CDN URL" do
      url = User.avatar_url(sample_user())
      assert url == "https://cdn.discordapp.com/avatars/123/abc123.png"
    end

    test "returns nil when no avatar" do
      user = User.from_raw(%{"id" => "1"})
      assert User.avatar_url(user) == nil
    end
  end

  describe "display_name/1" do
    test "returns global_name when set" do
      assert User.display_name(sample_user()) == "Alice"
    end

    test "falls back to username" do
      user = User.from_raw(%{"id" => "1", "username" => "bob"})
      assert User.display_name(user) == "bob"
    end
  end

  describe "bot?/1" do
    test "returns true for bot users" do
      user = User.from_raw(%{"id" => "1", "bot" => true})
      assert User.bot?(user) == true
    end

    test "returns false for non-bot users" do
      assert User.bot?(sample_user()) == false
    end

    test "returns false when bot is nil" do
      user = User.from_raw(%{"id" => "1"})
      assert User.bot?(user) == false
    end
  end

  describe "Access behaviour" do
    test "bracket access with string key" do
      user = sample_user()
      assert user["username"] == "alice"
    end

    test "bracket access with atom key" do
      user = sample_user()
      assert user[:username] == "alice"
    end
  end

  # ── Entity Manager ──

  setup do
    bypass = Bypass.open()
    Application.put_env(:eda, :base_url, "http://localhost:#{bypass.port}")
    Application.put_env(:eda, :token, "test-token")

    on_exit(fn ->
      Application.delete_env(:eda, :base_url)
    end)

    {:ok, bypass: bypass}
  end

  defp json(conn, body) do
    conn
    |> Plug.Conn.put_resp_content_type("application/json")
    |> Plug.Conn.resp(200, Jason.encode!(body))
  end

  describe "fetch/1" do
    test "returns a User struct from REST", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/users/123", fn conn ->
        json(conn, %{"id" => "123", "username" => "alice"})
      end)

      assert {:ok, %User{id: "123", username: "alice"}} = User.fetch("123")
    end
  end

  describe "create_dm/1" do
    test "returns a Channel struct", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/users/@me/channels", fn conn ->
        json(conn, %{"id" => "dm1", "type" => 1})
      end)

      assert {:ok, %EDA.Channel{id: "dm1", type: :dm}} = User.create_dm("123")
    end
  end
end
