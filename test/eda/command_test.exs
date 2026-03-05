defmodule EDA.CommandTest do
  use ExUnit.Case, async: true

  import EDA.Command
  import EDA.Command.Option, except: [to_map: 1]

  describe "slash/2" do
    test "creates a slash command" do
      cmd = slash("ping", "Pings the bot")
      assert cmd.name == "ping"
      assert cmd.description == "Pings the bot"
      assert cmd.type == 1
      assert cmd.options == []
    end

    test "allows hyphens and underscores" do
      cmd = slash("my-cmd_test", "A test")
      assert cmd.name == "my-cmd_test"
    end

    test "raises on empty name" do
      assert_raise ArgumentError, ~r/1-32 characters/, fn ->
        slash("", "desc")
      end
    end

    test "raises on name over 32 characters" do
      assert_raise ArgumentError, ~r/1-32 characters/, fn ->
        slash(String.duplicate("a", 33), "desc")
      end
    end

    test "raises on uppercase name" do
      assert_raise ArgumentError, ~r/lowercase/, fn ->
        slash("Hello", "desc")
      end
    end

    test "raises on name with spaces" do
      assert_raise ArgumentError, ~r/invalid/, fn ->
        slash("my cmd", "desc")
      end
    end

    test "raises on empty description" do
      assert_raise ArgumentError, ~r/1-100 characters/, fn ->
        slash("ping", "")
      end
    end

    test "raises on description over 100 characters" do
      assert_raise ArgumentError, ~r/1-100 characters/, fn ->
        slash("ping", String.duplicate("a", 101))
      end
    end
  end

  describe "user_command/1" do
    test "creates a user context menu command" do
      cmd = user_command("User Info")
      assert cmd.name == "User Info"
      assert cmd.type == 2
      assert cmd.description == ""
    end

    test "allows uppercase and spaces" do
      cmd = user_command("Get User Info")
      assert cmd.name == "Get User Info"
    end

    test "raises on name over 32 characters" do
      assert_raise ArgumentError, ~r/1-32 characters/, fn ->
        user_command(String.duplicate("a", 33))
      end
    end
  end

  describe "message_command/1" do
    test "creates a message context menu command" do
      cmd = message_command("Quote Message")
      assert cmd.name == "Quote Message"
      assert cmd.type == 3
    end
  end

  describe "option/2" do
    test "adds an option to a slash command" do
      cmd =
        slash("greet", "Greet someone")
        |> option(string("name", "The name"))

      assert length(cmd.options) == 1
      assert hd(cmd.options).name == "name"
    end

    test "appends options in order" do
      cmd =
        slash("test", "Test")
        |> option(string("a", "First"))
        |> option(string("b", "Second"))
        |> option(string("c", "Third"))

      assert Enum.map(cmd.options, & &1.name) == ["a", "b", "c"]
    end

    test "raises when adding more than 25 options" do
      cmd =
        Enum.reduce(1..25, slash("test", "Test"), fn i, acc ->
          option(acc, string("opt-#{i}", "Option #{i}"))
        end)

      assert_raise ArgumentError, ~r/more than 25/, fn ->
        option(cmd, string("opt-26", "Option 26"))
      end
    end

    test "raises when adding options to user command" do
      assert_raise ArgumentError, ~r/user commands cannot have options/, fn ->
        user_command("Test") |> option(string("x", "Y"))
      end
    end

    test "raises when adding options to message command" do
      assert_raise ArgumentError, ~r/message commands cannot have options/, fn ->
        message_command("Test") |> option(string("x", "Y"))
      end
    end
  end

  describe "default_member_permissions/2" do
    test "sets permissions" do
      cmd = slash("admin", "Admin only") |> default_member_permissions("8")
      assert cmd.default_member_permissions == "8"
    end
  end

  describe "nsfw/2" do
    test "sets nsfw flag" do
      cmd = slash("nsfw-cmd", "NSFW") |> nsfw()
      assert cmd.nsfw == true
    end

    test "can unset nsfw" do
      cmd = slash("safe", "Safe") |> nsfw(false)
      assert cmd.nsfw == false
    end
  end

  describe "contexts/2" do
    test "sets context types" do
      cmd = slash("ping", "Pong") |> contexts([:guild, :bot_dm])
      assert cmd.contexts == [0, 1]
    end

    test "supports all context types" do
      cmd = slash("ping", "Pong") |> contexts([:guild, :bot_dm, :private_channel])
      assert cmd.contexts == [0, 1, 2]
    end

    test "raises on unknown context" do
      assert_raise ArgumentError, ~r/unknown context/, fn ->
        slash("ping", "Pong") |> contexts([:invalid])
      end
    end
  end

  describe "to_map/1" do
    test "serializes simple slash command" do
      map = slash("ping", "Pings the bot") |> to_map()

      assert map == %{name: "ping", description: "Pings the bot", type: 1}
    end

    test "omits empty options" do
      map = slash("ping", "Pong") |> to_map()
      refute Map.has_key?(map, :options)
    end

    test "omits nil permissions" do
      map = slash("ping", "Pong") |> to_map()
      refute Map.has_key?(map, :default_member_permissions)
    end

    test "omits nsfw when false" do
      map = slash("ping", "Pong") |> to_map()
      refute Map.has_key?(map, :nsfw)
    end

    test "omits nil contexts" do
      map = slash("ping", "Pong") |> to_map()
      refute Map.has_key?(map, :contexts)
    end

    test "omits empty description for context menu commands" do
      map = user_command("Test") |> to_map()
      refute Map.has_key?(map, :description)
    end

    test "includes options when present" do
      map =
        slash("greet", "Greet")
        |> option(string("msg", "Message", required: true))
        |> to_map()

      assert [%{type: 3, name: "msg", description: "Message", required: true}] = map[:options]
    end

    test "serializes full command" do
      map =
        slash("test", "Test command")
        |> option(string("query", "Search query", required: true))
        |> default_member_permissions("8")
        |> nsfw()
        |> contexts([:guild])
        |> to_map()

      assert map[:name] == "test"
      assert map[:description] == "Test command"
      assert map[:type] == 1
      assert map[:default_member_permissions] == "8"
      assert map[:nsfw] == true
      assert map[:contexts] == [0]
      assert length(map[:options]) == 1
    end
  end

  describe "Jason.Encoder" do
    test "encodes command to JSON" do
      json =
        slash("ping", "Pong")
        |> Jason.encode!()
        |> Jason.decode!()

      assert json["name"] == "ping"
      assert json["description"] == "Pong"
      assert json["type"] == 1
    end

    test "encodes command with options" do
      json =
        slash("test", "Test")
        |> option(string("q", "Query", required: true))
        |> Jason.encode!()
        |> Jason.decode!()

      assert [%{"type" => 3, "name" => "q", "required" => true}] = json["options"]
    end
  end

  # ── Localization ───────────────────────────────────────────────────

  describe "localize/3" do
    test "adds name and description localizations to command" do
      cmd =
        slash("ping", "Pings the bot")
        |> EDA.Command.localize("fr", name: "ping", description: "Ping le bot")
        |> EDA.Command.localize("de", description: "Pingt den Bot")

      map = EDA.Command.to_map(cmd)

      assert map.name_localizations == %{"fr" => "ping"}
      assert map.description_localizations == %{"fr" => "Ping le bot", "de" => "Pingt den Bot"}
    end

    test "omits localizations from to_map when not set" do
      map = slash("ping", "Pong") |> EDA.Command.to_map()

      refute Map.has_key?(map, :name_localizations)
      refute Map.has_key?(map, :description_localizations)
    end

    test "localizes option name and description" do
      opt =
        string("query", "Search query")
        |> EDA.Command.Option.localize("fr", name: "requête", description: "Requête de recherche")
        |> EDA.Command.Option.localize("ja", description: "検索クエリ")

      map = EDA.Command.Option.to_map(opt)

      assert map.name_localizations == %{"fr" => "requête"}

      assert map.description_localizations == %{
               "fr" => "Requête de recherche",
               "ja" => "検索クエリ"
             }
    end

    test "option without localizations omits fields" do
      map = string("q", "Query") |> EDA.Command.Option.to_map()

      refute Map.has_key?(map, :name_localizations)
      refute Map.has_key?(map, :description_localizations)
    end

    test "localizations survive JSON roundtrip" do
      json =
        slash("greet", "Greet someone")
        |> EDA.Command.localize("es-ES", name: "saludar", description: "Saluda a alguien")
        |> option(
          string("message", "The greeting")
          |> EDA.Command.Option.localize("es-ES", name: "mensaje", description: "El saludo")
        )
        |> Jason.encode!()
        |> Jason.decode!()

      assert json["name_localizations"] == %{"es-ES" => "saludar"}
      assert json["description_localizations"] == %{"es-ES" => "Saluda a alguien"}

      [opt] = json["options"]
      assert opt["name_localizations"] == %{"es-ES" => "mensaje"}
      assert opt["description_localizations"] == %{"es-ES" => "El saludo"}
    end
  end
end
