defmodule EDA.RoleColorsTest do
  use ExUnit.Case, async: true

  alias EDA.Role
  alias EDA.Role.Colors

  doctest EDA.Role.Colors

  describe "from_raw/1" do
    test "parses the three documented keys" do
      colors =
        Colors.from_raw(%{
          "primary_color" => 10_382_335,
          "secondary_color" => 12_427_263,
          "tertiary_color" => nil
        })

      assert colors.primary_color == 10_382_335
      assert colors.secondary_color == 12_427_263
      assert colors.tertiary_color == nil
    end

    test "nil and non-maps give nil rather than raising" do
      assert Colors.from_raw(nil) == nil
      assert Colors.from_raw("nope") == nil
    end
  end

  describe "style/1 — three styles, as in JDA and discord.js" do
    test "only a primary colour is solid" do
      assert Colors.style(%Colors{primary_color: 1}) == :solid
      assert Colors.style(nil) == :solid
    end

    test "a secondary colour makes it a gradient" do
      assert Colors.style(%Colors{primary_color: 1, secondary_color: 2}) == :gradient
    end

    test "a tertiary colour makes it holographic, not a gradient" do
      assert Colors.style(Colors.holographic()) == :holographic

      assert Colors.style(%Colors{primary_color: 1, secondary_color: 2, tertiary_color: 3}) ==
               :holographic
    end

    test "the predicates agree with style/1 and are mutually exclusive" do
      for colors <- [
            %Colors{primary_color: 1},
            %Colors{primary_color: 1, secondary_color: 2},
            Colors.holographic()
          ] do
        flags = [
          Colors.solid?(colors),
          Colors.gradient?(colors),
          Colors.holographic?(colors)
        ]

        assert Enum.count(flags, & &1) == 1, "expected exactly one style for #{inspect(colors)}"
      end
    end

    test "gradient?/1 is false for holographic — this was the bug" do
      refute Colors.gradient?(Colors.holographic())
      refute Colors.gradient?(%Colors{primary_color: 1, tertiary_color: 3})
    end
  end

  describe "constructors" do
    test "solid/1" do
      assert Colors.solid(255) == %Colors{primary_color: 255}
    end

    test "gradient/2" do
      assert Colors.gradient(1, 2) == %Colors{primary_color: 1, secondary_color: 2}
    end

    test "holographic/0 uses the values Discord enforces" do
      holo = Colors.holographic()

      assert holo.primary_color == 11_127_295
      assert holo.secondary_color == 16_759_788
      assert holo.tertiary_color == 16_761_760
    end

    test "the enforced values are exposed individually" do
      assert Colors.holographic_primary() == 11_127_295
      assert Colors.holographic_secondary() == 16_759_788
      assert Colors.holographic_tertiary() == 16_761_760
    end
  end

  describe "to_map/1" do
    test "uses the snake_case keys Discord expects" do
      assert Colors.to_map(Colors.gradient(1, 2)) == %{primary_color: 1, secondary_color: 2}
    end

    test "omits nil keys rather than sending null" do
      map = Colors.to_map(Colors.solid(255))

      assert map == %{primary_color: 255}
      refute Map.has_key?(map, :secondary_color)
      refute Map.has_key?(map, :tertiary_color)
    end

    test "keeps all three for holographic" do
      assert Colors.to_map(Colors.holographic()) == %{
               primary_color: 11_127_295,
               secondary_color: 16_759_788,
               tertiary_color: 16_761_760
             }
    end
  end

  describe "Jason.Encoder" do
    test "encodes to the API shape, so a struct can be sent directly" do
      assert Jason.decode!(Jason.encode!(Colors.gradient(1, 2))) == %{
               "primary_color" => 1,
               "secondary_color" => 2
             }
    end
  end

  describe "EDA.Role integration" do
    # Shape taken verbatim from a real guild (2026-09-19).
    @raw_role %{
      "id" => "937349188189044786",
      "name" => "･𝑩𝒂𝒘𝒊𝒌𝒙",
      "color" => 10_382_335,
      "colors" => %{
        "primary_color" => 10_382_335,
        "secondary_color" => 12_427_263,
        "tertiary_color" => nil
      },
      "position" => 5,
      "permissions" => "0"
    }

    test "from_raw/1 parses colors into a struct" do
      role = Role.from_raw(@raw_role)

      assert %Colors{} = role.colors
      assert role.colors.primary_color == 10_382_335
      assert role.colors.secondary_color == 12_427_263
    end

    test "the legacy color field is preserved" do
      assert Role.from_raw(@raw_role).color == 10_382_335
    end

    test "a role without colors still parses" do
      role = Role.from_raw(%{"id" => "1", "name" => "plain", "color" => 42})

      assert role.colors == nil
      assert role.color == 42
    end

    test "primary_color/1 prefers colors, falling back to the deprecated field" do
      assert Role.primary_color(Role.from_raw(@raw_role)) == 10_382_335
      assert Role.primary_color(%Role{color: 7}) == 7
      assert Role.primary_color(%Role{color: 7, colors: %Colors{primary_color: 9}}) == 9
    end

    test "primary_color/1 falls back when colors carries a nil primary" do
      assert Role.primary_color(%Role{color: 7, colors: %Colors{primary_color: nil}}) == 7
    end

    test "style/1, gradient?/1 and holographic?/1 read through the role" do
      role = Role.from_raw(@raw_role)

      assert Role.style(role) == :gradient
      assert Role.gradient?(role)
      refute Role.holographic?(role)

      holo = %Role{colors: Colors.holographic()}

      assert Role.style(holo) == :holographic
      assert Role.holographic?(holo)
      refute Role.gradient?(holo)

      assert Role.style(%Role{color: 1}) == :solid
    end
  end
end
