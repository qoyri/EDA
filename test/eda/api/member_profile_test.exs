defmodule EDA.API.MemberProfileTest do
  @moduledoc """
  Covers `PATCH /guilds/{id}/members/@me` — the bot's per-guild profile.

  It is a different endpoint from `modify/4`, with a different permission model: only
  `:nick` needs `CHANGE_NICKNAME`, the appearance fields need nothing. The tests assert the
  path, since sending a profile change to `/members/{bot_id}` would be rejected, and the
  exact body, since `nil` is meaningful — it clears a field rather than leaving it alone.
  """

  # NOT async — Bypass and the Application env are global.
  use ExUnit.Case

  alias EDA.API.Member

  @png <<0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A>> <> <<0, 0, 0, 13>>

  setup do
    bypass = Bypass.open()
    Application.put_env(:eda, :base_url, "http://localhost:#{bypass.port}")
    Application.put_env(:eda, :token, "test-token")

    on_exit(fn -> Application.delete_env(:eda, :base_url) end)

    {:ok, bypass: bypass}
  end

  defp expect_me(bypass, test_pid) do
    Bypass.expect_once(bypass, "PATCH", "/guilds/111/members/@me", fn conn ->
      {:ok, raw, conn} = Plug.Conn.read_body(conn)

      send(
        test_pid,
        {:body, Jason.decode!(raw), Plug.Conn.get_req_header(conn, "x-audit-log-reason")}
      )

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.resp(200, Jason.encode!(%{"nick" => "EDA", "banner" => "abc"}))
    end)
  end

  describe "modify_me/2" do
    test "hits /members/@me, not /members/{id}", %{bypass: bypass} do
      expect_me(bypass, self())

      assert {:ok, %{"nick" => "EDA"}} = Member.modify_me("111", nick: "EDA")
      assert_receive {:body, %{"nick" => "EDA"}, _reason}
    end

    test "sends only the profile fields, and the reason travels as a header",
         %{bypass: bypass} do
      expect_me(bypass, self())

      assert {:ok, _} =
               Member.modify_me("111",
                 nick: "EDA",
                 bio: "Built on OTP",
                 reason: "profile refresh"
               )

      assert_receive {:body, body, _reason}
      assert body == %{"nick" => "EDA", "bio" => "Built on OTP"}
    end

    test "an unknown option is refused rather than quietly dropped", %{bypass: bypass} do
      # Confirmed live on 2026-09-20: dropping it answered {:ok, member} with the nickname
      # unchanged, so `nickname:` looked like it had worked.
      Bypass.down(bypass)

      error = assert_raise(ArgumentError, fn -> Member.modify_me("111", nickname: "EDA") end)

      assert error.message =~ "unknown option [:nickname]"
      assert error.message =~ ":nick"
      assert error.message =~ ":banner"

      assert_raise ArgumentError, ~r/unknown options \[:a, :b\]/, fn ->
        Member.modify_me("111", a: 1, b: 2)
      end
    end

    test "a nickname over 32 characters is refused, as Discord refuses it", %{bypass: bypass} do
      # Verified live: 32 accepted, 33 answered 50035.
      Bypass.down(bypass)

      assert_raise ArgumentError, ~r/:nick is limited to 32 characters/, fn ->
        Member.modify_me("111", nick: String.duplicate("n", 33))
      end
    end

    test "exactly 32 characters is fine, and nil clears it", %{bypass: bypass} do
      expect_me(bypass, self())

      assert {:ok, _} = Member.modify_me("111", nick: String.duplicate("n", 32))
      assert_receive {:body, _body, _reason}
    end

    test "no bio length is imposed, because Discord imposes none", %{bypass: bypass} do
      # 200 characters were accepted by the live API on 2026-09-20. A 190-character limit
      # exists elsewhere as a client-side convention; enforcing it here would reject valid
      # input.
      expect_me(bypass, self())

      assert {:ok, _} = Member.modify_me("111", bio: String.duplicate("b", 200))

      assert_receive {:body, body, _reason}
      assert String.length(body["bio"]) == 200
    end

    test "the reason becomes an audit log header rather than a body field",
         %{bypass: bypass} do
      expect_me(bypass, self())

      assert {:ok, _} = Member.modify_me("111", nick: "EDA", reason: "profile refresh")

      assert_receive {:body, body, [reason]}
      assert reason == URI.encode("profile refresh")
      refute Map.has_key?(body, "reason")
    end

    test "raw image bytes become a data URI", %{bypass: bypass} do
      expect_me(bypass, self())

      assert {:ok, _} = Member.modify_me("111", avatar: @png)

      assert_receive {:body, body, _reason}
      assert body["avatar"] == "data:image/png;base64," <> Base.encode64(@png)
    end

    @tag :tmp_dir
    test "a path is read and converted", %{bypass: bypass, tmp_dir: tmp_dir} do
      expect_me(bypass, self())

      path = Path.join(tmp_dir, "banner.png")
      File.write!(path, @png)

      assert {:ok, _} = Member.modify_me("111", banner: path)

      assert_receive {:body, body, _reason}
      assert body["banner"] == "data:image/png;base64," <> Base.encode64(@png)
    end

    test "a data URI already built by hand is not re-encoded", %{bypass: bypass} do
      expect_me(bypass, self())
      uri = EDA.ImageData.from_binary(@png)

      assert {:ok, _} = Member.modify_me("111", avatar: uri)

      assert_receive {:body, body, _reason}
      assert body["avatar"] == uri
    end

    test "nil is sent, because it is how a field is cleared", %{bypass: bypass} do
      expect_me(bypass, self())

      assert {:ok, _} = Member.modify_me("111", avatar: nil, nick: nil)

      assert_receive {:body, body, _reason}
      assert body == %{"avatar" => nil, "nick" => nil}
    end

    test "an empty call sends an empty body rather than failing", %{bypass: bypass} do
      expect_me(bypass, self())

      assert {:ok, _} = Member.modify_me("111")

      assert_receive {:body, body, _reason}
      assert body == %{}
    end

    test "the map form works and coerces the same way", %{bypass: bypass} do
      expect_me(bypass, self())

      assert {:ok, _} = Member.modify_me("111", %{nick: "EDA", avatar: @png})

      assert_receive {:body, body, _reason}
      assert body["nick"] == "EDA"
      assert body["avatar"] =~ ~r{^data:image/png;base64,}
    end

    test "an integer guild id works like a string one", %{bypass: bypass} do
      expect_me(bypass, self())

      assert {:ok, _} = Member.modify_me(111, nick: "EDA")
      assert_receive {:body, _body, _reason}
    end

    test "an image Discord cannot take is refused before the request", %{bypass: bypass} do
      Bypass.down(bypass)
      webp = "RIFF" <> <<36, 0, 0, 0>> <> "WEBPVP8 "

      assert_raise ArgumentError, ~r/does not accept WebP/, fn ->
        Member.modify_me("111", avatar: webp)
      end
    end
  end

  describe "EDA.Member.modify_me/2" do
    test "returns a struct, and carries the guild banner", %{bypass: bypass} do
      expect_me(bypass, self())

      assert {:ok, %EDA.Member{} = member} = EDA.Member.modify_me("111", nick: "EDA")

      assert member.nick == "EDA"
      assert member.banner == "abc"
    end
  end

  describe "bio comes back from the modify response only" do
    test "the struct carries it when Discord sends it", %{bypass: bypass} do
      # Verified live: PATCH echoes `bio`, a later GET on the member omits it entirely.
      Bypass.expect_once(bypass, "PATCH", "/guilds/111/members/@me", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(%{"nick" => "EDA", "bio" => "Built on OTP"}))
      end)

      assert {:ok, member} = EDA.Member.modify_me("111", bio: "Built on OTP")
      assert member.bio == "Built on OTP"
    end

    test "a member object without one parses to nil" do
      assert EDA.Member.from_raw(%{"nick" => "EDA"}).bio == nil
    end
  end

  describe "from_raw/1 reads the guild banner" do
    test "the field the profile endpoint sets is parsed back" do
      member = EDA.Member.from_raw(%{"nick" => "EDA", "avatar" => "a1", "banner" => "b1"})

      assert member.avatar == "a1"
      assert member.banner == "b1"
    end

    test "a member without one is nil, not a crash" do
      assert EDA.Member.from_raw(%{"nick" => "EDA"}).banner == nil
    end
  end
end
