defmodule EDA.EmbedTest do
  use ExUnit.Case, async: true

  import EDA.Embed

  describe "new/0" do
    test "returns an empty embed struct" do
      embed = new()
      assert %EDA.Embed{} = embed
      assert embed.title == nil
      assert embed.description == nil
      assert embed.url == nil
      assert embed.timestamp == nil
      assert embed.color == nil
      assert embed.footer == nil
      assert embed.image == nil
      assert embed.thumbnail == nil
      assert embed.author == nil
      assert embed.fields == []
    end
  end

  describe "title/2" do
    test "sets the title" do
      embed = new() |> title("Hello")
      assert embed.title == "Hello"
    end

    test "raises when title exceeds 256 characters" do
      assert_raise ArgumentError, ~r/title must be at most 256/, fn ->
        new() |> title(String.duplicate("a", 257))
      end
    end

    test "allows exactly 256 characters" do
      embed = new() |> title(String.duplicate("a", 256))
      assert String.length(embed.title) == 256
    end
  end

  describe "description/2" do
    test "sets the description" do
      embed = new() |> description("Some text")
      assert embed.description == "Some text"
    end

    test "raises when description exceeds 4096 characters" do
      assert_raise ArgumentError, ~r/description must be at most 4096/, fn ->
        new() |> description(String.duplicate("a", 4097))
      end
    end

    test "allows exactly 4096 characters" do
      embed = new() |> description(String.duplicate("a", 4096))
      assert String.length(embed.description) == 4096
    end
  end

  describe "url/2" do
    test "sets the url" do
      embed = new() |> url("https://example.com")
      assert embed.url == "https://example.com"
    end
  end

  describe "timestamp/2" do
    test "converts DateTime to ISO 8601" do
      {:ok, dt, _} = DateTime.from_iso8601("2024-01-15T12:00:00Z")
      embed = new() |> timestamp(dt)
      assert embed.timestamp == "2024-01-15T12:00:00Z"
    end

    test "converts NaiveDateTime to ISO 8601 with Z suffix" do
      ndt = ~N[2024-01-15 12:00:00]
      embed = new() |> timestamp(ndt)
      assert embed.timestamp == "2024-01-15T12:00:00Z"
    end

    test "passes through raw string" do
      embed = new() |> timestamp("2024-01-15T12:00:00.000Z")
      assert embed.timestamp == "2024-01-15T12:00:00.000Z"
    end
  end

  describe "color/2" do
    test "accepts integer" do
      embed = new() |> color(0xFF0000)
      assert embed.color == 0xFF0000
    end

    test "accepts zero" do
      embed = new() |> color(0)
      assert embed.color == 0
    end

    test "accepts max value 0xFFFFFF" do
      embed = new() |> color(0xFFFFFF)
      assert embed.color == 0xFFFFFF
    end

    test "raises on negative integer" do
      assert_raise ArgumentError, ~r/color must be between 0 and/, fn ->
        new() |> color(-1)
      end
    end

    test "raises on integer above 0xFFFFFF" do
      assert_raise ArgumentError, ~r/color must be between 0 and/, fn ->
        new() |> color(0x1000000)
      end
    end

    test "accepts known color atoms" do
      embed = new() |> color(:blurple)
      assert embed.color == 0x5865F2

      embed = new() |> color(:red)
      assert embed.color == 0xED4245
    end

    test "raises on unknown color atom" do
      assert_raise ArgumentError, ~r/unknown color/, fn ->
        new() |> color(:nope)
      end
    end

    test "parses 6-digit hex with #" do
      embed = new() |> color("#FF0000")
      assert embed.color == 0xFF0000
    end

    test "parses 6-digit hex without #" do
      embed = new() |> color("FF0000")
      assert embed.color == 0xFF0000
    end

    test "parses 3-digit hex shorthand" do
      embed = new() |> color("#F00")
      assert embed.color == 0xFF0000
    end

    test "parses 3-digit hex shorthand without #" do
      embed = new() |> color("F00")
      assert embed.color == 0xFF0000
    end

    test "parses lowercase hex" do
      embed = new() |> color("#ff0000")
      assert embed.color == 0xFF0000
    end

    test "raises on invalid hex length" do
      assert_raise ArgumentError, ~r/invalid hex color/, fn ->
        new() |> color("#FF00")
      end
    end

    test "raises on invalid hex characters" do
      assert_raise ArgumentError, ~r/invalid hex color/, fn ->
        new() |> color("#GGGGGG")
      end
    end
  end

  describe "footer/3" do
    test "sets footer with text only" do
      embed = new() |> footer("Footer text")
      assert embed.footer == %{text: "Footer text"}
    end

    test "sets footer with icon_url" do
      embed = new() |> footer("Footer", icon_url: "https://example.com/icon.png")
      assert embed.footer == %{text: "Footer", icon_url: "https://example.com/icon.png"}
    end

    test "raises when footer text exceeds 2048 characters" do
      assert_raise ArgumentError, ~r/footer text must be at most 2048/, fn ->
        new() |> footer(String.duplicate("a", 2049))
      end
    end
  end

  describe "author/3" do
    test "sets author with name only" do
      embed = new() |> author("Author")
      assert embed.author == %{name: "Author"}
    end

    test "sets author with all options" do
      embed =
        new()
        |> author("Author", url: "https://example.com", icon_url: "https://example.com/icon.png")

      assert embed.author == %{
               name: "Author",
               url: "https://example.com",
               icon_url: "https://example.com/icon.png"
             }
    end

    test "raises when author name exceeds 256 characters" do
      assert_raise ArgumentError, ~r/author name must be at most 256/, fn ->
        new() |> author(String.duplicate("a", 257))
      end
    end
  end

  describe "thumbnail/2" do
    test "sets thumbnail url" do
      embed = new() |> thumbnail("https://example.com/thumb.png")
      assert embed.thumbnail == %{url: "https://example.com/thumb.png"}
    end
  end

  describe "image/2" do
    test "sets image url" do
      embed = new() |> image("https://example.com/image.png")
      assert embed.image == %{url: "https://example.com/image.png"}
    end
  end

  describe "field/4" do
    test "adds a field" do
      embed = new() |> field("Name", "Value")
      assert embed.fields == [%{name: "Name", value: "Value", inline: false}]
    end

    test "adds an inline field" do
      embed = new() |> field("Name", "Value", inline: true)
      assert embed.fields == [%{name: "Name", value: "Value", inline: true}]
    end

    test "appends fields in order" do
      embed =
        new()
        |> field("First", "1")
        |> field("Second", "2")
        |> field("Third", "3")

      assert length(embed.fields) == 3
      assert Enum.at(embed.fields, 0).name == "First"
      assert Enum.at(embed.fields, 1).name == "Second"
      assert Enum.at(embed.fields, 2).name == "Third"
    end

    test "raises when field name exceeds 256 characters" do
      assert_raise ArgumentError, ~r/field name must be at most 256/, fn ->
        new() |> field(String.duplicate("a", 257), "value")
      end
    end

    test "raises when field value exceeds 1024 characters" do
      assert_raise ArgumentError, ~r/field value must be at most 1024/, fn ->
        new() |> field("name", String.duplicate("a", 1025))
      end
    end

    test "raises when adding more than 25 fields" do
      embed =
        Enum.reduce(1..25, new(), fn i, acc ->
          field(acc, "Field #{i}", "Value #{i}")
        end)

      assert_raise ArgumentError, ~r/more than 25 fields/, fn ->
        field(embed, "Field 26", "Value 26")
      end
    end
  end

  describe "validate/1" do
    test "returns {:ok, embed} when under 6000 chars" do
      embed = new() |> title("Hello") |> description("World")
      assert {:ok, ^embed} = validate(embed)
    end

    test "returns {:ok, embed} for empty embed" do
      assert {:ok, _} = validate(new())
    end

    test "returns error when total chars exceed 6000" do
      embed =
        new()
        |> title(String.duplicate("a", 256))
        |> description(String.duplicate("b", 4096))
        |> footer(String.duplicate("c", 2048))

      assert {:error, [reason]} = validate(embed)
      assert reason =~ "exceeds 6000"
    end

    test "counts field name and value in total" do
      embed =
        new()
        |> description(String.duplicate("a", 4096))
        |> footer(String.duplicate("b", 1000))
        |> field(String.duplicate("c", 256), String.duplicate("d", 1024))

      assert {:error, _} = validate(embed)
    end
  end

  describe "validate!/1" do
    test "returns embed when valid" do
      embed = new() |> title("Hello")
      assert ^embed = validate!(embed)
    end

    test "raises on invalid embed" do
      embed =
        new()
        |> title(String.duplicate("a", 256))
        |> description(String.duplicate("b", 4096))
        |> footer(String.duplicate("c", 2048))

      assert_raise ArgumentError, ~r/exceeds 6000/, fn ->
        validate!(embed)
      end
    end
  end

  describe "to_map/1" do
    test "strips nil values" do
      map = new() |> title("Hello") |> to_map()
      assert map == %{title: "Hello"}
      refute Map.has_key?(map, :description)
      refute Map.has_key?(map, :url)
      refute Map.has_key?(map, :fields)
    end

    test "strips empty fields list" do
      map = new() |> title("Hello") |> to_map()
      refute Map.has_key?(map, :fields)
    end

    test "includes non-empty fields" do
      map = new() |> field("Name", "Value") |> to_map()
      assert [%{name: "Name", value: "Value", inline: false}] = map[:fields]
    end

    test "includes all set properties" do
      embed =
        new()
        |> title("Title")
        |> description("Desc")
        |> color(0xFF0000)
        |> url("https://example.com")
        |> footer("Footer")
        |> author("Author")
        |> thumbnail("https://thumb.png")
        |> image("https://image.png")

      map = to_map(embed)

      assert map[:title] == "Title"
      assert map[:description] == "Desc"
      assert map[:color] == 0xFF0000
      assert map[:url] == "https://example.com"
      assert map[:footer] == %{text: "Footer"}
      assert map[:author] == %{name: "Author"}
      assert map[:thumbnail] == %{url: "https://thumb.png"}
      assert map[:image] == %{url: "https://image.png"}
    end
  end

  describe "Jason.Encoder" do
    test "encodes embed to JSON" do
      embed = new() |> title("Hello") |> color(:red)
      json = Jason.encode!(embed)
      decoded = Jason.decode!(json)

      assert decoded["title"] == "Hello"
      assert decoded["color"] == 0xED4245
    end

    test "omits nil fields from JSON" do
      json = new() |> title("Hello") |> Jason.encode!() |> Jason.decode!()
      refute Map.has_key?(json, "description")
      refute Map.has_key?(json, "fields")
      refute Map.has_key?(json, "footer")
    end

    test "encodes full embed with all properties" do
      {:ok, dt, _} = DateTime.from_iso8601("2024-01-15T12:00:00Z")

      embed =
        new()
        |> title("Title")
        |> description("Description")
        |> color("#5865F2")
        |> url("https://example.com")
        |> timestamp(dt)
        |> footer("Footer", icon_url: "https://example.com/icon.png")
        |> author("Author",
          url: "https://example.com",
          icon_url: "https://example.com/avatar.png"
        )
        |> thumbnail("https://example.com/thumb.png")
        |> image("https://example.com/image.png")
        |> field("Field 1", "Value 1")
        |> field("Field 2", "Value 2", inline: true)

      decoded = embed |> Jason.encode!() |> Jason.decode!()

      assert decoded["title"] == "Title"
      assert decoded["description"] == "Description"
      assert decoded["color"] == 0x5865F2
      assert decoded["url"] == "https://example.com"
      assert decoded["timestamp"] == "2024-01-15T12:00:00Z"
      assert decoded["footer"]["text"] == "Footer"
      assert decoded["footer"]["icon_url"] == "https://example.com/icon.png"
      assert decoded["author"]["name"] == "Author"
      assert decoded["author"]["url"] == "https://example.com"
      assert decoded["author"]["icon_url"] == "https://example.com/avatar.png"
      assert decoded["thumbnail"]["url"] == "https://example.com/thumb.png"
      assert decoded["image"]["url"] == "https://example.com/image.png"
      assert length(decoded["fields"]) == 2
      assert Enum.at(decoded["fields"], 0)["name"] == "Field 1"
      assert Enum.at(decoded["fields"], 1)["inline"] == true
    end
  end

  describe "pipe chaining" do
    test "full builder pipeline works" do
      embed =
        new()
        |> title("Test")
        |> description("A test embed")
        |> color(:blurple)
        |> url("https://example.com")
        |> timestamp("2024-01-15T12:00:00Z")
        |> footer("Footer", icon_url: "https://example.com/icon.png")
        |> author("Author", url: "https://example.com")
        |> thumbnail("https://example.com/thumb.png")
        |> image("https://example.com/image.png")
        |> field("Field 1", "Value 1")
        |> field("Field 2", "Value 2", inline: true)

      assert embed.title == "Test"
      assert embed.description == "A test embed"
      assert embed.color == 0x5865F2
      assert embed.url == "https://example.com"
      assert embed.timestamp == "2024-01-15T12:00:00Z"
      assert embed.footer.text == "Footer"
      assert embed.author.name == "Author"
      assert embed.thumbnail.url == "https://example.com/thumb.png"
      assert embed.image.url == "https://example.com/image.png"
      assert length(embed.fields) == 2
      assert {:ok, ^embed} = validate(embed)
    end
  end

  # ── Presets ────────────────────────────────────────────────────────

  describe "error/1" do
    test "creates red embed with description" do
      embed = error("Something went wrong")
      assert embed.color == 0xED4245
      assert embed.description == "Something went wrong"
    end

    test "is pipeable" do
      embed = error("Oops") |> title("Error")
      assert embed.title == "Error"
      assert embed.description == "Oops"
    end
  end

  describe "success/1" do
    test "creates green embed with description" do
      embed = success("User banned")
      assert embed.color == 0x57F287
      assert embed.description == "User banned"
    end

    test "is pipeable" do
      embed = success("Done") |> footer("All clear")
      assert embed.footer.text == "All clear"
      assert embed.description == "Done"
    end
  end
end
