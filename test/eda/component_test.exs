defmodule EDA.ComponentTest do
  use ExUnit.Case, async: true

  import EDA.Component

  # ── Container ──────────────────────────────────────────────────────

  describe "container/1" do
    test "creates a container with components" do
      c = container(components: [text_display("Hello")])
      assert c.type == 17
      assert length(c.components) == 1
    end

    test "accepts accent_color" do
      c = container(accent_color: 0xFF0000, components: [text_display("Hi")])
      assert c.accent_color == 0xFF0000
    end

    test "accepts spoiler" do
      c = container(spoiler: true, components: [text_display("Secret")])
      assert c.spoiler == true
    end

    test "raises without components" do
      assert_raise ArgumentError, ~r/requires :components/, fn ->
        container([])
      end
    end

    test "raises on empty components list" do
      assert_raise ArgumentError, ~r/non-empty list/, fn ->
        container(components: [])
      end
    end

    test "raises on more than 10 components" do
      components = Enum.map(1..11, fn i -> text_display("Text #{i}") end)

      assert_raise ArgumentError, ~r/more than 10/, fn ->
        container(components: components)
      end
    end
  end

  # ── Action Row ─────────────────────────────────────────────────────

  describe "action_row/1" do
    test "creates an action row with buttons" do
      row = action_row([button("Click", custom_id: "btn1")])
      assert row.type == 1
      assert length(row.components) == 1
    end

    test "allows up to 5 buttons" do
      buttons = Enum.map(1..5, fn i -> button("Btn #{i}", custom_id: "btn_#{i}") end)
      row = action_row(buttons)
      assert length(row.components) == 5
    end

    test "allows one select menu" do
      row = action_row([string_select("sel", [select_option("A", "a")])])
      assert row.type == 1
    end

    test "raises on empty components" do
      assert_raise ArgumentError, ~r/at least one/, fn ->
        action_row([])
      end
    end

    test "raises on more than 5 buttons" do
      buttons = Enum.map(1..6, fn i -> button("Btn #{i}", custom_id: "btn_#{i}") end)

      assert_raise ArgumentError, ~r/more than 5/, fn ->
        action_row(buttons)
      end
    end

    test "raises on mixing select and buttons" do
      assert_raise ArgumentError, ~r/cannot mix/, fn ->
        action_row([
          button("Click", custom_id: "btn"),
          string_select("sel", [select_option("A", "a")])
        ])
      end
    end

    test "raises on multiple selects" do
      assert_raise ArgumentError, ~r/only contain one select/, fn ->
        action_row([
          user_select("sel1"),
          user_select("sel2")
        ])
      end
    end
  end

  # ── Section ────────────────────────────────────────────────────────

  describe "section/2" do
    test "creates a section with single text and accessory" do
      s = section(text_display("Hello"), accessory: thumbnail("https://example.com/img.png"))
      assert s.type == 9
      assert length(s.components) == 1
      assert s.accessory.type == 11
    end

    test "creates a section with multiple texts and accessory" do
      s =
        section([text_display("A"), text_display("B"), text_display("C")],
          accessory: button("Click", custom_id: "btn")
        )

      assert length(s.components) == 3
      assert s.accessory.type == 2
    end

    test "raises when accessory is missing" do
      assert_raise ArgumentError, ~r/section requires an :accessory/, fn ->
        section(text_display("Hello"))
      end
    end

    test "accepts thumbnail accessory" do
      s = section(text_display("Hi"), accessory: thumbnail("https://example.com/img.png"))
      assert s.accessory.type == 11
    end

    test "accepts button accessory" do
      s = section(text_display("Hi"), accessory: button("Click", custom_id: "btn"))
      assert s.accessory.type == 2
    end

    test "raises on empty texts" do
      assert_raise ArgumentError, ~r/1–3/, fn ->
        section([])
      end
    end

    test "raises on more than 3 texts" do
      texts = Enum.map(1..4, fn i -> text_display("T#{i}") end)

      assert_raise ArgumentError, ~r/1–3/, fn ->
        section(texts)
      end
    end

    test "raises on non-text_display components" do
      assert_raise ArgumentError, ~r/must all be text_display/, fn ->
        section([separator()])
      end
    end

    test "raises on invalid accessory" do
      assert_raise ArgumentError, ~r/must be a thumbnail or button/, fn ->
        section(text_display("Hi"), accessory: separator())
      end
    end
  end

  # ── Separator ──────────────────────────────────────────────────────

  describe "separator/1" do
    test "creates a default separator" do
      s = separator()
      assert s.type == 14
      refute Map.has_key?(s, :divider)
      refute Map.has_key?(s, :spacing)
    end

    test "accepts divider option" do
      s = separator(divider: true)
      assert s.divider == true
    end

    test "accepts spacing :small" do
      s = separator(spacing: :small)
      assert s.spacing == 1
    end

    test "accepts spacing :large" do
      s = separator(spacing: :large)
      assert s.spacing == 2
    end

    test "raises on invalid spacing" do
      assert_raise ArgumentError, ~r/:small or :large/, fn ->
        separator(spacing: :medium)
      end
    end
  end

  # ── Text Display ───────────────────────────────────────────────────

  describe "text_display/1" do
    test "creates a text display" do
      t = text_display("# Hello")
      assert t.type == 10
      assert t.content == "# Hello"
    end

    test "raises on empty content" do
      assert_raise ArgumentError, ~r/cannot be empty/, fn ->
        text_display("")
      end
    end
  end

  # ── Thumbnail ──────────────────────────────────────────────────────

  describe "thumbnail/2" do
    test "creates a thumbnail" do
      t = thumbnail("https://example.com/img.png")
      assert t.type == 11
      assert t.media == %{url: "https://example.com/img.png"}
    end

    test "accepts description" do
      t = thumbnail("https://example.com/img.png", description: "Nice")
      assert t.description == "Nice"
    end

    test "accepts spoiler" do
      t = thumbnail("https://example.com/img.png", spoiler: true)
      assert t.spoiler == true
    end

    test "raises on empty url" do
      assert_raise ArgumentError, ~r/cannot be empty/, fn ->
        thumbnail("")
      end
    end
  end

  # ── Media Gallery ──────────────────────────────────────────────────

  describe "media_gallery/1" do
    test "creates a media gallery" do
      g = media_gallery([media_item("https://example.com/a.png")])
      assert g.type == 12
      assert length(g.items) == 1
    end

    test "accepts up to 10 items" do
      items = Enum.map(1..10, fn i -> media_item("https://example.com/#{i}.png") end)
      g = media_gallery(items)
      assert length(g.items) == 10
    end

    test "raises on empty items" do
      assert_raise ArgumentError, ~r/1–10/, fn ->
        media_gallery([])
      end
    end

    test "raises on more than 10 items" do
      items = Enum.map(1..11, fn i -> media_item("https://example.com/#{i}.png") end)

      assert_raise ArgumentError, ~r/1–10/, fn ->
        media_gallery(items)
      end
    end
  end

  # ── Media Item ─────────────────────────────────────────────────────

  describe "media_item/2" do
    test "creates a media item" do
      m = media_item("https://example.com/img.png")
      assert m.media == %{url: "https://example.com/img.png"}
    end

    test "accepts description and spoiler" do
      m = media_item("https://example.com/img.png", description: "Photo", spoiler: true)
      assert m.description == "Photo"
      assert m.spoiler == true
    end

    test "raises on empty url" do
      assert_raise ArgumentError, ~r/cannot be empty/, fn ->
        media_item("")
      end
    end
  end

  # ── File ───────────────────────────────────────────────────────────

  describe "file/2" do
    test "creates a file component" do
      f = file("attachment://report.pdf")
      assert f.type == 13
      assert f.file == %{url: "attachment://report.pdf"}
    end

    test "accepts spoiler" do
      f = file("attachment://secret.zip", spoiler: true)
      assert f.spoiler == true
    end

    test "raises on non-attachment url" do
      assert_raise ArgumentError, ~r/attachment:\/\//, fn ->
        file("https://example.com/file.pdf")
      end
    end
  end

  # ── Button ─────────────────────────────────────────────────────────

  describe "button/2" do
    test "creates a button with custom_id" do
      b = button("Click", custom_id: "btn_1")
      assert b.type == 2
      assert b.style == 2
      assert b.label == "Click"
      assert b.custom_id == "btn_1"
    end

    test "accepts all style atoms" do
      assert button("A", custom_id: "a", style: :primary).style == 1
      assert button("B", custom_id: "b", style: :secondary).style == 2
      assert button("C", custom_id: "c", style: :success).style == 3
      assert button("D", custom_id: "d", style: :danger).style == 4
      assert button("E", url: "https://example.com", style: :link).style == 5
    end

    test "link button requires url" do
      b = button("Visit", style: :link, url: "https://example.com")
      assert b.url == "https://example.com"
      refute Map.has_key?(b, :custom_id)
    end

    test "accepts emoji" do
      b = button("Like", custom_id: "like", emoji: %{name: "👍"})
      assert b.emoji == %{name: "👍"}
    end

    test "accepts disabled" do
      b = button("Off", custom_id: "off", disabled: true)
      assert b.disabled == true
    end

    test "raises on label over 80 chars" do
      assert_raise ArgumentError, ~r/80 characters/, fn ->
        button(String.duplicate("a", 81), custom_id: "x")
      end
    end

    test "raises on unknown style" do
      assert_raise ArgumentError, ~r/unknown button style/, fn ->
        button("X", custom_id: "x", style: :fancy)
      end
    end

    test "raises on link button without url" do
      assert_raise ArgumentError, ~r/requires :url/, fn ->
        button("X", style: :link)
      end
    end

    test "raises on non-link button without custom_id" do
      assert_raise ArgumentError, ~r/requires :custom_id/, fn ->
        button("X", style: :primary)
      end
    end

    test "raises on custom_id over 100 chars" do
      assert_raise ArgumentError, ~r/100 characters/, fn ->
        button("X", custom_id: String.duplicate("a", 101))
      end
    end
  end

  # ── Link Button ────────────────────────────────────────────────────

  describe "link_button/3" do
    test "creates a link button" do
      b = link_button("Visit", "https://example.com")
      assert b.style == 5
      assert b.url == "https://example.com"
      assert b.label == "Visit"
    end

    test "passes through options" do
      b = link_button("Docs", "https://docs.com", emoji: %{name: "📚"})
      assert b.emoji == %{name: "📚"}
    end
  end

  # ── String Select ──────────────────────────────────────────────────

  describe "string_select/3" do
    test "creates a string select" do
      s =
        string_select("color", [
          select_option("Red", "red"),
          select_option("Blue", "blue")
        ])

      assert s.type == 3
      assert s.custom_id == "color"
      assert length(s.options) == 2
    end

    test "accepts placeholder" do
      s =
        string_select("sel", [select_option("A", "a")], placeholder: "Pick one")

      assert s.placeholder == "Pick one"
    end

    test "accepts min/max values" do
      s =
        string_select("sel", [select_option("A", "a")],
          min_values: 1,
          max_values: 3
        )

      assert s.min_values == 1
      assert s.max_values == 3
    end

    test "raises on empty options" do
      assert_raise ArgumentError, ~r/1–25/, fn ->
        string_select("sel", [])
      end
    end

    test "raises on more than 25 options" do
      opts = Enum.map(1..26, fn i -> select_option("Opt #{i}", "#{i}") end)

      assert_raise ArgumentError, ~r/1–25/, fn ->
        string_select("sel", opts)
      end
    end

    test "raises on custom_id over 100 chars" do
      assert_raise ArgumentError, ~r/100 characters/, fn ->
        string_select(String.duplicate("a", 101), [select_option("A", "a")])
      end
    end
  end

  # ── Select Option ──────────────────────────────────────────────────

  describe "select_option/3" do
    test "creates a select option" do
      o = select_option("Red", "red")
      assert o.label == "Red"
      assert o.value == "red"
    end

    test "accepts description" do
      o = select_option("Red", "red", description: "The color red")
      assert o.description == "The color red"
    end

    test "accepts emoji and default" do
      o = select_option("Red", "red", emoji: %{name: "🔴"}, default: true)
      assert o.emoji == %{name: "🔴"}
      assert o.default == true
    end

    test "raises on label over 100 chars" do
      assert_raise ArgumentError, ~r/label.*100/, fn ->
        select_option(String.duplicate("a", 101), "val")
      end
    end

    test "raises on value over 100 chars" do
      assert_raise ArgumentError, ~r/value.*100/, fn ->
        select_option("Label", String.duplicate("a", 101))
      end
    end

    test "raises on description over 100 chars" do
      assert_raise ArgumentError, ~r/description.*100/, fn ->
        select_option("Label", "val", description: String.duplicate("a", 101))
      end
    end
  end

  # ── Auto-Populated Selects ────────────────────────────────────────

  describe "user_select/2" do
    test "creates a user select" do
      s = user_select("pick_user")
      assert s.type == 5
      assert s.custom_id == "pick_user"
    end

    test "accepts placeholder" do
      s = user_select("pick_user", placeholder: "Choose")
      assert s.placeholder == "Choose"
    end
  end

  describe "role_select/2" do
    test "creates a role select" do
      s = role_select("pick_role")
      assert s.type == 6
      assert s.custom_id == "pick_role"
    end
  end

  describe "mentionable_select/2" do
    test "creates a mentionable select" do
      s = mentionable_select("pick_mention")
      assert s.type == 7
      assert s.custom_id == "pick_mention"
    end
  end

  describe "channel_select/2" do
    test "creates a channel select" do
      s = channel_select("pick_channel")
      assert s.type == 8
      assert s.custom_id == "pick_channel"
    end

    test "accepts channel_types" do
      s = channel_select("ch", channel_types: [:guild_text, :guild_voice])
      assert s.channel_types == [0, 2]
    end

    test "raises on unknown channel type" do
      assert_raise ArgumentError, ~r/unknown channel type/, fn ->
        channel_select("ch", channel_types: [:fake])
      end
    end
  end

  # ── Full Composition ──────────────────────────────────────────────

  describe "composition" do
    test "builds a complete v2 message" do
      msg =
        container(
          accent_color: 0x5865F2,
          components: [
            text_display("# Welcome!"),
            separator(spacing: :large),
            section(
              text_display("Check out this feature"),
              accessory: thumbnail("https://example.com/thumb.png")
            ),
            media_gallery([
              media_item("https://example.com/img1.png", description: "Image 1"),
              media_item("https://example.com/img2.png")
            ]),
            action_row([
              button("Click", custom_id: "btn_1", style: :primary),
              link_button("Visit", "https://example.com")
            ])
          ]
        )

      assert msg.type == 17
      assert msg.accent_color == 0x5865F2
      assert length(msg.components) == 5
    end

    test "all maps are JSON-encodable" do
      msg =
        container(
          components: [
            text_display("Hello"),
            action_row([button("OK", custom_id: "ok", style: :success)])
          ]
        )

      assert {:ok, json} = Jason.encode(msg)
      decoded = Jason.decode!(json)
      assert decoded["type"] == 17
      assert length(decoded["components"]) == 2
    end
  end

  # ── disable_all ──────────────────────────────────────────────────────

  describe "disable_all/1" do
    test "disables buttons in action row" do
      row =
        action_row([
          button("A", custom_id: "a"),
          button("B", custom_id: "b")
        ])

      [disabled_row] = disable_all([row])
      assert Enum.all?(disabled_row.components, &(&1.disabled == true))
    end

    test "disables select menus" do
      row =
        action_row([
          string_select("select1", [
            select_option("Option 1", "1"),
            select_option("Option 2", "2")
          ])
        ])

      [disabled_row] = disable_all([row])
      [select] = disabled_row.components
      assert select.disabled == true
    end

    test "preserves non-interactive components" do
      text = text_display("Hello")
      sep = separator()

      result = disable_all([text, sep])
      assert result == [text, sep]
    end

    test "handles string-keyed components from Discord API" do
      row = %{
        "type" => 1,
        "components" => [
          %{"type" => 2, "label" => "Click", "custom_id" => "btn1"},
          %{"type" => 3, "custom_id" => "sel1", "options" => []}
        ]
      }

      [disabled_row] = disable_all([row])
      assert Enum.all?(disabled_row["components"], &(&1["disabled"] == true))
    end

    test "handles deeply nested components" do
      components = [
        action_row([
          button("A", custom_id: "a"),
          button("B", custom_id: "b")
        ]),
        action_row([
          string_select("s1", [select_option("X", "x")])
        ])
      ]

      result = disable_all(components)

      Enum.each(result, fn row ->
        Enum.each(row.components, fn c ->
          assert c.disabled == true
        end)
      end)
    end
  end
end
