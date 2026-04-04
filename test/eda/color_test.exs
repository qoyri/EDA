defmodule EDA.ColorTest do
  use ExUnit.Case, async: true

  alias EDA.Color

  describe "random/0" do
    test "returns a value in valid range" do
      for _ <- 1..100 do
        color = Color.random()
        assert color >= 0 and color <= 0xFFFFFF
      end
    end

    test "produces different values across calls" do
      colors = for _ <- 1..50, do: Color.random()
      unique = Enum.uniq(colors)
      # With 16.7M possible values, 50 calls should produce at least 45 unique
      assert length(unique) >= 45
    end
  end

  describe "resolve/1" do
    test "resolves named colors" do
      assert Color.resolve(:blurple) == 0x5865F2
      assert Color.resolve(:red) == 0xED4245
    end

    test "resolves :random" do
      color = Color.resolve(:random)
      assert color >= 0 and color <= 0xFFFFFF
    end

    test "passes through integers" do
      assert Color.resolve(0xFF0000) == 0xFF0000
    end

    test "parses hex strings" do
      assert Color.resolve("#FF0000") == 0xFF0000
      assert Color.resolve("FF0000") == 0xFF0000
      assert Color.resolve("#F00") == 0xFF0000
    end

    test "raises on unknown name" do
      assert_raise ArgumentError, ~r/unknown color/, fn ->
        Color.resolve(:nonexistent)
      end
    end
  end

  describe "named color functions" do
    test "each named color has a function" do
      assert Color.blurple() == 0x5865F2
      assert Color.red() == 0xED4245
      assert Color.green() == 0x57F287
      assert Color.pink() == 0xFF69B4
      assert Color.coral() == 0xFF7F50
    end
  end

  describe "all/0 and all_names/0" do
    test "all returns a map of colors" do
      colors = Color.all()
      assert is_map(colors)
      assert colors[:blurple] == 0x5865F2
    end

    test "all_names returns sorted atoms" do
      names = Color.all_names()
      assert is_list(names)
      assert :blurple in names
      assert :random not in names
      assert names == Enum.sort(names)
    end
  end

  describe "Embed integration" do
    test "color(:random) sets a random color on embed" do
      import EDA.Embed

      embed = new() |> color(:random)
      assert embed.color >= 0 and embed.color <= 0xFFFFFF
    end

    test "two embeds with :random get different colors" do
      import EDA.Embed

      colors = for _ <- 1..20, do: (new() |> color(:random)).color
      unique = Enum.uniq(colors)
      assert length(unique) >= 18
    end
  end
end
