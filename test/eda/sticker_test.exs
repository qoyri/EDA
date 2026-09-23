defmodule EDA.StickerTest do
  use ExUnit.Case, async: true

  alias EDA.Sticker

  describe "from_raw/1" do
    test "parses all fields and resolves type/format atoms" do
      raw = %{
        "id" => "s1",
        "pack_id" => "p1",
        "name" => "wave",
        "description" => "A waving sticker",
        "tags" => "wave,hi",
        "type" => 2,
        "format_type" => 1,
        "available" => true,
        "guild_id" => "g1",
        "user" => %{"id" => "u1"},
        "sort_value" => 5
      }

      sticker = Sticker.from_raw(raw)
      assert %Sticker{} = sticker
      assert sticker.id == "s1"
      assert sticker.pack_id == "p1"
      assert sticker.name == "wave"
      assert sticker.description == "A waving sticker"
      assert sticker.tags == "wave,hi"
      assert sticker.type == :guild
      assert sticker.format_type == :png
      assert sticker.available == true
      assert sticker.guild_id == "g1"
      assert %EDA.User{id: "u1"} = sticker.user
      assert sticker.sort_value == 5
    end

    test "resolves standard type" do
      sticker = Sticker.from_raw(%{"type" => 1})
      assert sticker.type == :standard
    end

    test "resolves all format types" do
      assert Sticker.from_raw(%{"format_type" => 1}).format_type == :png
      assert Sticker.from_raw(%{"format_type" => 2}).format_type == :apng
      assert Sticker.from_raw(%{"format_type" => 3}).format_type == :lottie
      assert Sticker.from_raw(%{"format_type" => 4}).format_type == :gif
    end

    test "keeps unknown type/format as integer" do
      sticker = Sticker.from_raw(%{"type" => 99, "format_type" => 99})
      assert sticker.type == 99
      assert sticker.format_type == 99
    end

    test "handles nil type/format" do
      sticker = Sticker.from_raw(%{})
      assert sticker.type == nil
      assert sticker.format_type == nil
    end
  end

  describe "cdn_url/1" do
    test "returns nil when id is nil" do
      assert Sticker.cdn_url(%Sticker{id: nil}) == nil
    end

    test "returns .json URL for lottie format" do
      url = Sticker.cdn_url(%Sticker{id: "1", format_type: :lottie})
      assert url == "https://cdn.discordapp.com/stickers/1.json"
    end

    test "returns .gif URL for gif format" do
      url = Sticker.cdn_url(%Sticker{id: "1", format_type: :gif})
      assert url == "https://cdn.discordapp.com/stickers/1.gif"
    end

    test "returns .png URL for png format" do
      url = Sticker.cdn_url(%Sticker{id: "1", format_type: :png})
      assert url == "https://cdn.discordapp.com/stickers/1.png"
    end

    test "returns .png URL for apng format" do
      url = Sticker.cdn_url(%Sticker{id: "1", format_type: :apng})
      assert url == "https://cdn.discordapp.com/stickers/1.png"
    end
  end
end
