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

  describe "gradient?/1" do
    test "solid colours are not gradients" do
      refute Colors.gradient?(%Colors{primary_color: 1})

      refute Colors.gradient?(%Colors{primary_color: 1, secondary_color: nil, tertiary_color: nil})
    end

    test "a secondary or tertiary colour makes it a gradient" do
      assert Colors.gradient?(%Colors{primary_color: 1, secondary_color: 2})
      assert Colors.gradient?(%Colors{primary_color: 1, tertiary_color: 3})
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

    test "gradient?/1 reads through the role" do
      assert Role.gradient?(Role.from_raw(@raw_role))
      refute Role.gradient?(%Role{color: 1})
    end
  end
end
