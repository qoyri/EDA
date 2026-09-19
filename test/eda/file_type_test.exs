defmodule EDA.FileTypeTest do
  @moduledoc """
  Covers the file type filters, and the validation EDA does before Discord sees them.

  The failure worth preventing is a filter that is *accepted* and matches nothing — writing
  `"pdf"` instead of `".pdf"`, or `"images"` instead of `"image"`. Discord would take either
  without complaint and simply show the user no files, so the errors are raised here.
  """

  use ExUnit.Case, async: true

  alias EDA.FileType

  doctest EDA.FileType

  describe "groups/0" do
    test "carries Discord's own expansions" do
      assert FileType.groups()[:image] == ~w(.png .gif .jpg .jpeg .jfif .webp .avif)
      assert FileType.groups()[:video] == ~w(.mp4 .mov .qt .webm)
      assert FileType.groups()[:audio] == ~w(.mp3 .m4a .wav .ogg .opus .flac)
    end

    test "there are exactly three, and no more are invented" do
      assert Enum.sort(Map.keys(FileType.groups())) == [:audio, :image, :video]
    end
  end

  describe "normalize!/1" do
    test "atoms and strings both name a group" do
      assert FileType.normalize!([:image, "video", :audio]) == ["image", "video", "audio"]
    end

    test "extensions are lowercased, since Discord treats the case alike" do
      assert FileType.normalize!([".PDF", ".Zip"]) == [".pdf", ".zip"]
    end

    test "a group name given in mixed case is still a group" do
      assert FileType.normalize!(["IMAGE"]) == ["image"]
    end

    test "order is preserved" do
      assert FileType.normalize!([".pdf", :image]) == [".pdf", "image"]
    end

    test "an empty list is fine — it means no filtering" do
      assert FileType.normalize!([]) == []
    end

    test "exactly ten is allowed, eleven is not" do
      ten = Enum.map(1..10, &".e#{&1}")
      assert length(FileType.normalize!(ten)) == 10

      assert_raise ArgumentError, ~r/at most 10 file types/, fn ->
        FileType.normalize!(ten ++ [".e11"])
      end
    end

    test "an extension without its dot is refused, not silently passed on" do
      # Discord would accept "pdf" as an unknown group name and filter nothing.
      assert_raise ArgumentError, ~r/dot-prefixed extension/, fn ->
        FileType.normalize!(["pdf"])
      end
    end

    test "a group name that does not exist is refused" do
      assert_raise ArgumentError, ~r/invalid file type "images"/, fn ->
        FileType.normalize!(["images"])
      end

      assert_raise ArgumentError, ~r/invalid file type :picture/, fn ->
        FileType.normalize!([:picture])
      end
    end

    test "a bare dot is not an extension" do
      assert_raise ArgumentError, ~r/invalid file type/, fn -> FileType.normalize!(["."]) end
    end

    test "the error names the groups, so the fix is obvious" do
      error = assert_raise(ArgumentError, fn -> FileType.normalize!(["nope"]) end)
      message = error.message

      assert message =~ ":image"
      assert message =~ ":video"
      assert message =~ ":audio"
      assert message =~ ".pdf"
    end

    test "a non-list is refused with a message about the option, not about an element" do
      assert_raise ArgumentError, ~r/:file_types must be a list/, fn ->
        FileType.normalize!(:image)
      end
    end

    test "a value of the wrong type is refused" do
      assert_raise ArgumentError, ~r/invalid file type 42/, fn -> FileType.normalize!([42]) end
      assert_raise ArgumentError, ~r/invalid file type nil/, fn -> FileType.normalize!([nil]) end
    end
  end

  describe "expand/1" do
    test "a group becomes its extensions" do
      assert FileType.expand([:video]) == [".mov", ".mp4", ".qt", ".webm"]
    end

    test "groups and extensions mix, deduplicated" do
      # .webp is already in the image group
      assert FileType.expand([:image, ".webp", ".pdf"]) ==
               [".avif", ".gif", ".jfif", ".jpeg", ".jpg", ".pdf", ".png", ".webp"]
    end

    test "nothing in, nothing out" do
      assert FileType.expand([]) == []
    end

    test "invalid filters raise here too, rather than expanding to nothing" do
      assert_raise ArgumentError, fn -> FileType.expand(["pdf"]) end
    end
  end

  describe "equivalent?/2" do
    test "order does not matter — Discord returns its own" do
      # Verified live on 2026-09-19: ["image", ".pdf"] reads back as [".pdf", "image"].
      assert FileType.equivalent?(["image", ".pdf"], [".pdf", :image])
    end

    test "a group equals the extensions it stands for" do
      assert FileType.equivalent?([:video], [".mp4", ".mov", ".qt", ".webm"])
    end

    test "duplicates do not make a difference" do
      assert FileType.equivalent?([".pdf", ".PDF"], [".pdf"])
    end

    test "a real difference is still a difference" do
      refute FileType.equivalent?([:image], [:image, ".pdf"])
      refute FileType.equivalent?([], [:image])
    end
  end

  describe "matches?/2" do
    test "matches a group by extension, ignoring case" do
      assert FileType.matches?("holiday.JPG", [:image])
      assert FileType.matches?("clip.MP4", [:video])
      assert FileType.matches?("song.flac", [:audio])
    end

    test "rejects an extension outside the filters" do
      refute FileType.matches?("notes.txt", [:image, ".pdf"])
      refute FileType.matches?("song.flac", [:image])
    end

    test "an explicit extension matches" do
      assert FileType.matches?("report.pdf", [".pdf"])
      assert FileType.matches?("REPORT.PDF", [".pdf"])
    end

    test "no filters accepts anything, as an option without :file_types does" do
      assert FileType.matches?("anything.xyz", [])
      assert FileType.matches?("no_extension", [])
    end

    test "a file with no extension passes no filter" do
      refute FileType.matches?("README", [:image])
      refute FileType.matches?("", [:image])
    end

    test "only the last extension counts, which is what Discord looks at" do
      assert FileType.matches?("archive.tar.gz", [".gz"])
      refute FileType.matches?("archive.tar.gz", [".tar"])
    end

    test "it is an extension check, so a renamed file passes — by design" do
      # This is the whole caveat: the filter says nothing about the contents.
      assert FileType.matches?("payload.exe.png", [:image])
    end
  end
end
