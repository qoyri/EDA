defmodule EDA.Command.OptionTest do
  use ExUnit.Case, async: true

  import EDA.Command.Option

  # ── Type Constructors ───────────────────────────────────────────────

  describe "string/3" do
    test "creates a string option" do
      opt = string("query", "Search query")
      assert opt.type == :string
      assert opt.name == "query"
      assert opt.description == "Search query"
    end

    test "accepts required option" do
      opt = string("query", "Search", required: true)
      assert opt.required == true
    end

    test "accepts min_length and max_length" do
      opt = string("query", "Search", min_length: 1, max_length: 100)
      assert opt.min_length == 1
      assert opt.max_length == 100
    end

    test "accepts choices" do
      opt = string("color", "Pick", choices: [{"Red", "red"}, {"Blue", "blue"}])
      assert [%{name: "Red", value: "red"}, %{name: "Blue", value: "blue"}] = opt.choices
    end

    test "accepts autocomplete" do
      opt = string("query", "Search", autocomplete: true)
      assert opt.autocomplete == true
    end

    test "raises on choices + autocomplete" do
      assert_raise ArgumentError, ~r/mutually exclusive/, fn ->
        string("x", "Y", choices: [{"A", "a"}], autocomplete: true)
      end
    end

    test "raises on more than 25 choices" do
      choices = Enum.map(1..26, fn i -> {"Choice #{i}", "#{i}"} end)

      assert_raise ArgumentError, ~r/more than 25 choices/, fn ->
        string("x", "Y", choices: choices)
      end
    end

    test "raises on choice name over 100 chars" do
      assert_raise ArgumentError, ~r/choice name must be 1-100/, fn ->
        string("x", "Y", choices: [{String.duplicate("a", 101), "val"}])
      end
    end

    test "raises on string choice value over 100 chars" do
      assert_raise ArgumentError, ~r/choice value must be at most 100/, fn ->
        string("x", "Y", choices: [{"name", String.duplicate("a", 101)}])
      end
    end

    test "rejects invalid options" do
      assert_raise ArgumentError, ~r/unexpected options.*min_value/, fn ->
        string("x", "Y", min_value: 5)
      end
    end
  end

  describe "integer/3" do
    test "creates an integer option" do
      opt = integer("count", "How many")
      assert opt.type == :integer
    end

    test "accepts min_value and max_value" do
      opt = integer("count", "How many", min_value: 1, max_value: 100)
      assert opt.min_value == 1
      assert opt.max_value == 100
    end

    test "accepts choices with integer values" do
      opt = integer("size", "Pick size", choices: [{"Small", 1}, {"Large", 10}])
      assert [%{name: "Small", value: 1}, %{name: "Large", value: 10}] = opt.choices
    end

    test "rejects invalid options for integer" do
      assert_raise ArgumentError, ~r/unexpected options.*min_length/, fn ->
        integer("x", "Y", min_length: 1)
      end
    end
  end

  describe "boolean/3" do
    test "creates a boolean option" do
      opt = boolean("ephemeral", "Only visible to you")
      assert opt.type == :boolean
    end

    test "accepts required" do
      opt = boolean("flag", "A flag", required: true)
      assert opt.required == true
    end

    test "rejects choices on boolean" do
      assert_raise ArgumentError, ~r/unexpected options.*choices/, fn ->
        boolean("x", "Y", choices: [{"Yes", true}])
      end
    end
  end

  describe "user/3" do
    test "creates a user option" do
      opt = user("target", "Who to mention")
      assert opt.type == :user
    end
  end

  describe "channel/3" do
    test "creates a channel option" do
      opt = channel("channel", "Where to post")
      assert opt.type == :channel
    end

    test "accepts channel_types" do
      opt = channel("ch", "Channel", channel_types: [:guild_text, :guild_voice])
      assert opt.channel_types == [:guild_text, :guild_voice]
    end

    test "raises on unknown channel type" do
      assert_raise ArgumentError, ~r/unknown channel type/, fn ->
        channel("ch", "Channel", channel_types: [:fake])
      end
    end
  end

  describe "role/3" do
    test "creates a role option" do
      opt = role("role", "The role")
      assert opt.type == :role
    end
  end

  describe "mentionable/3" do
    test "creates a mentionable option" do
      opt = mentionable("who", "User or role")
      assert opt.type == :mentionable
    end
  end

  describe "number/3" do
    test "creates a number option" do
      opt = number("amount", "How much")
      assert opt.type == :number
    end

    test "accepts float min/max values" do
      opt = number("rate", "Rate", min_value: 0.1, max_value: 99.9)
      assert opt.min_value == 0.1
      assert opt.max_value == 99.9
    end
  end

  describe "attachment/3" do
    test "creates an attachment option" do
      opt = attachment("file", "Upload a file")
      assert opt.type == :attachment
    end

    test "file_types narrows the picker and is normalised" do
      opt = attachment("receipt", "Proof of purchase", file_types: [:image, ".PDF"])

      assert opt.file_types == ["image", ".pdf"]
    end

    test "file_types reaches the wire" do
      map = attachment("f", "A file", file_types: [:image]) |> EDA.Command.Option.to_map()

      assert map[:file_types] == ["image"]
    end

    test "no file_types means no key at all, rather than an empty list" do
      map = attachment("f", "A file") |> EDA.Command.Option.to_map()

      refute Map.has_key?(map, :file_types)
    end

    test "an invalid filter is refused when the option is built" do
      assert_raise ArgumentError, ~r/dot-prefixed extension/, fn ->
        attachment("f", "A file", file_types: ["pdf"])
      end
    end

    test "file_types is rejected on option types that do not take it" do
      # Discord only accepts it on ATTACHMENT; sending it elsewhere is a silent no-op.
      assert_raise ArgumentError, ~r/unexpected options \[:file_types\]/, fn ->
        string("q", "A query", file_types: [:image])
      end

      assert_raise ArgumentError, ~r/unexpected options \[:file_types\]/, fn ->
        channel("c", "A channel", file_types: [:image])
      end
    end

    test "it still accepts :required alongside" do
      opt = attachment("f", "A file", required: true, file_types: [:audio])

      assert opt.required == true
      assert opt.file_types == ["audio"]
    end
  end

  # ── Sub Commands ────────────────────────────────────────────────────

  describe "sub_command/3" do
    test "creates a sub_command" do
      opt = sub_command("add", "Add something")
      assert opt.type == :sub_command
      assert opt.name == "add"
      assert opt.options == nil
    end

    test "accepts nested options" do
      opt =
        sub_command("add", "Add something", [
          string("name", "The name", required: true),
          integer("amount", "How many")
        ])

      assert length(opt.options) == 2
      assert hd(opt.options).type == :string
    end

    test "raises on more than 25 nested options" do
      opts = Enum.map(1..26, fn i -> string("opt-#{i}", "Option #{i}") end)

      assert_raise ArgumentError, ~r/more than 25/, fn ->
        sub_command("add", "Add", opts)
      end
    end
  end

  describe "sub_command_group/3" do
    test "creates a sub_command_group" do
      opt =
        sub_command_group("manage", "Manage things", [
          sub_command("add", "Add"),
          sub_command("remove", "Remove")
        ])

      assert opt.type == :sub_command_group
      assert length(opt.options) == 2
    end

    test "raises on empty sub_commands" do
      assert_raise ArgumentError, ~r/at least one sub_command/, fn ->
        sub_command_group("manage", "Manage", [])
      end
    end

    test "raises on non-sub_command children" do
      assert_raise ArgumentError, ~r/must be sub_commands/, fn ->
        sub_command_group("manage", "Manage", [
          string("x", "Y")
        ])
      end
    end
  end

  # ── Validation ──────────────────────────────────────────────────────

  describe "name validation" do
    test "raises on empty name" do
      assert_raise ArgumentError, ~r/1-32 characters/, fn ->
        string("", "desc")
      end
    end

    test "raises on name over 32 characters" do
      assert_raise ArgumentError, ~r/1-32 characters/, fn ->
        string(String.duplicate("a", 33), "desc")
      end
    end

    test "raises on uppercase name" do
      assert_raise ArgumentError, ~r/lowercase/, fn ->
        string("Hello", "desc")
      end
    end
  end

  describe "description validation" do
    test "raises on empty description" do
      assert_raise ArgumentError, ~r/1-100 characters/, fn ->
        string("x", "")
      end
    end

    test "raises on description over 100 characters" do
      assert_raise ArgumentError, ~r/1-100 characters/, fn ->
        string("x", String.duplicate("a", 101))
      end
    end
  end

  # ── Serialization ───────────────────────────────────────────────────

  describe "to_map/1" do
    test "serializes simple option" do
      map = string("query", "Search") |> to_map()
      assert map == %{type: 3, name: "query", description: "Search"}
    end

    test "includes required when set" do
      map = string("q", "Search", required: true) |> to_map()
      assert map[:required] == true
    end

    test "omits nil fields" do
      map = string("q", "Search") |> to_map()
      refute Map.has_key?(map, :required)
      refute Map.has_key?(map, :choices)
      refute Map.has_key?(map, :min_value)
      refute Map.has_key?(map, :autocomplete)
    end

    test "serializes choices" do
      map = string("c", "Color", choices: [{"Red", "red"}]) |> to_map()
      assert [%{name: "Red", value: "red"}] = map[:choices]
    end

    test "serializes sub_command with nested options" do
      map =
        sub_command("add", "Add", [
          string("name", "Name", required: true)
        ])
        |> to_map()

      assert map[:type] == 1
      assert [%{type: 3, name: "name", required: true}] = map[:options]
    end

    test "serializes channel_types" do
      map = channel("ch", "Channel", channel_types: [:guild_text]) |> to_map()
      assert map[:channel_types] == [0]
    end

    test "serializes min/max values" do
      map = integer("n", "Number", min_value: 1, max_value: 100) |> to_map()
      assert map[:min_value] == 1
      assert map[:max_value] == 100
    end

    test "serializes min/max length" do
      map = string("s", "Text", min_length: 1, max_length: 500) |> to_map()
      assert map[:min_length] == 1
      assert map[:max_length] == 500
    end
  end

  describe "Jason.Encoder" do
    test "encodes option to JSON" do
      json =
        string("query", "Search", required: true)
        |> Jason.encode!()
        |> Jason.decode!()

      assert json["type"] == 3
      assert json["name"] == "query"
      assert json["required"] == true
    end
  end
end
