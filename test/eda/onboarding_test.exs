defmodule EDA.OnboardingTest do
  @moduledoc """
  Guild onboarding: `GET` / `PUT /guilds/{id}/onboarding` and the `EDA.Onboarding` structs.

  Two behaviours were established against the live API before this was written, and these tests
  pin them:

    * Discord **returns** an option's emoji as an `emoji` object but only **accepts** the flat
      `emoji_id` / `emoji_name` / `emoji_animated` fields. Sending back what was read cleared the
      emoji (`"name" => nil`), so every request converts the object.
    * A new prompt without an `id` is refused (`BASE_TYPE_REQUIRED`); Discord then replaces the
      id it was given with its own. So builders fill in a placeholder.
  """

  # NOT async — Bypass and the Application env are global.
  use ExUnit.Case

  alias EDA.Onboarding
  alias EDA.Onboarding.{Option, Prompt}

  doctest EDA.Onboarding

  setup do
    bypass = Bypass.open()
    Application.put_env(:eda, :base_url, "http://localhost:#{bypass.port}")
    Application.put_env(:eda, :token, "test-token")
    on_exit(fn -> Application.delete_env(:eda, :base_url) end)
    {:ok, bypass: bypass}
  end

  defp capture(bypass, method, path, response) do
    test_pid = self()

    Bypass.expect_once(bypass, method, path, fn conn ->
      {:ok, raw, conn} = Plug.Conn.read_body(conn)
      body = if raw == "", do: nil, else: Jason.decode!(raw)
      send(test_pid, {:captured, body, Plug.Conn.get_req_header(conn, "x-audit-log-reason")})

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.resp(200, Jason.encode!(response))
    end)
  end

  # The shape of a real GET, emoji as an object, with undocumented fields alongside.
  @raw %{
    "guild_id" => "1",
    "enabled" => true,
    "mode" => 0,
    "default_channel_ids" => ["10", "11"],
    "below_requirements" => false,
    "responses" => [],
    "prompts" => [
      %{
        "id" => "100",
        "title" => "Age",
        "type" => 0,
        "single_select" => true,
        "required" => true,
        "in_onboarding" => true,
        "options" => [
          %{
            "id" => "200",
            "title" => "18+",
            "description" => "",
            "emoji" => %{"id" => "900", "name" => "B_18", "animated" => false},
            "channel_ids" => [],
            "role_ids" => ["300"]
          },
          %{
            "id" => "201",
            "title" => "Party",
            "description" => nil,
            "emoji" => %{"id" => nil, "name" => "🎉", "animated" => false},
            "channel_ids" => ["10"],
            "role_ids" => []
          },
          %{
            "id" => "202",
            "title" => "No emoji",
            "description" => nil,
            "emoji" => %{"id" => nil, "name" => nil, "animated" => false},
            "channel_ids" => ["11"],
            "role_ids" => []
          }
        ]
      }
    ]
  }

  describe "from_raw/1" do
    test "reads prompts, options and emojis" do
      onboarding = Onboarding.from_raw(@raw)

      assert %Onboarding{guild_id: "1", enabled: true, mode: :default} = onboarding

      [%Prompt{id: "100", type: :multiple_choice, single_select: true, options: [a, b, c]}] =
        onboarding.prompts

      assert %Option{emoji: %EDA.Emoji{id: "900", name: "B_18"}, role_ids: ["300"]} = a
      assert %EDA.Emoji{id: nil, name: "🎉"} = b.emoji
      # Discord sends an emoji object with nothing in it for an option without one.
      assert c.emoji == nil
    end
  end

  describe "the round trip" do
    test "save/2 sends every emoji in the flat form Discord accepts", %{bypass: bypass} do
      capture(bypass, "PUT", "/guilds/1/onboarding", @raw)

      assert {:ok, %Onboarding{}} = Onboarding.save(Onboarding.from_raw(@raw), reason: "tidy")

      assert_receive {:captured, body, ["tidy"]}
      [prompt] = body["prompts"]
      [a, b, c] = prompt["options"]

      assert Map.take(a, ~w(emoji_id emoji_name emoji_animated)) ==
               %{"emoji_id" => "900", "emoji_name" => "B_18", "emoji_animated" => false}

      assert Map.take(b, ~w(emoji_id emoji_name)) == %{"emoji_id" => nil, "emoji_name" => "🎉"}
      refute Map.has_key?(a, "emoji")
      refute Map.has_key?(c, "emoji_name")
      assert prompt["type"] == 0
      assert body["mode"] == 0
      assert body["default_channel_ids"] == ["10", "11"]
    end

    test "raw prompts sent back as read are converted too", %{bypass: bypass} do
      capture(bypass, "PUT", "/guilds/1/onboarding", @raw)

      assert {:ok, _} = EDA.API.Guild.modify_onboarding("1", prompts: @raw["prompts"])

      assert_receive {:captured, %{"prompts" => [%{"options" => [a | _]}]}, []}
      assert a["emoji_name"] == "B_18"
      refute Map.has_key?(a, "emoji")
    end
  end

  describe "builders" do
    test "a new prompt and option get placeholder ids, which Discord requires" do
      prompt = Onboarding.prompt("Q", [Onboarding.option("A", emoji: "🎮", role_ids: [5])])

      assert prompt.id =~ ~r/^\d+$/
      assert hd(prompt.options).id =~ ~r/^\d+$/
      refute prompt.id == hd(prompt.options).id
      assert hd(prompt.options).role_ids == ["5"]
      assert hd(prompt.options).emoji == %EDA.Emoji{name: "🎮"}
    end

    test "placeholders made together are distinct" do
      ids = for _ <- 1..50, do: Onboarding.option("A").id
      assert length(Enum.uniq(ids)) == 50
    end

    test "a custom emoji struct is kept whole" do
      emoji = %EDA.Emoji{id: "9", name: "party", animated: true}
      assert Onboarding.option("A", emoji: emoji).emoji == emoji
    end

    test "add_prompt/2 appends, remove_prompt/2 removes by id" do
      onboarding = Onboarding.from_raw(@raw)
      added = Onboarding.add_prompt(onboarding, Onboarding.prompt("New", [], id: "999"))

      assert Enum.map(added.prompts, & &1.id) == ["100", "999"]
      assert Enum.map(Onboarding.remove_prompt(added, "100").prompts, & &1.id) == ["999"]
    end

    test "dropdown prompts and advanced mode encode to Discord's integers" do
      onboarding = %Onboarding{
        mode: :advanced,
        prompts: [Onboarding.prompt("Q", [], type: :dropdown)]
      }

      body = Onboarding.to_payload(onboarding)

      assert body.mode == 1
      assert hd(body.prompts).type == 1
    end
  end

  describe "EDA.API.Guild" do
    test "onboarding/1 and fetch/1", %{bypass: bypass} do
      capture(bypass, "GET", "/guilds/1/onboarding", @raw)
      assert {:ok, %Onboarding{prompts: [_]}} = Onboarding.fetch("1")
    end

    test "modify_onboarding/2 translates the mode and refuses unknown options", %{bypass: bypass} do
      capture(bypass, "PUT", "/guilds/1/onboarding", @raw)
      assert {:ok, _} = EDA.API.Guild.modify_onboarding("1", enabled: false, mode: :advanced)
      assert_receive {:captured, %{"enabled" => false, "mode" => 1}, []}

      assert_raise ArgumentError, ~r/unknown option \[:prompt\]/, fn ->
        EDA.API.Guild.modify_onboarding("1", prompt: [])
      end

      assert_raise ArgumentError, ~r/:default or :advanced/, fn ->
        EDA.API.Guild.modify_onboarding("1", mode: :simple)
      end
    end
  end
end
