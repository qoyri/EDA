defmodule EDA.AttachmentFlagsTest do
  @moduledoc """
  Covers the attachment flag bitfield and the edit-request entries built by `keep/2`.

  The bit values and the `keep/2` semantics were checked against the live API on
  2026-09-19: uploading with `is_spoiler: true` and a clean filename comes back with
  `flags: 8`, and a later edit both sets and clears that flag on an attachment that already
  exists.
  """

  use ExUnit.Case, async: true

  import Bitwise

  alias EDA.Attachment

  # Nothing ran EDA.Attachment's documented examples before; this verifies them.
  doctest EDA.Attachment

  describe "flag constants match Discord's documented values" do
    test "the documented bit positions" do
      assert Attachment.flag_clip() == 1 <<< 0
      assert Attachment.flag_thumbnail() == 1 <<< 1
      assert Attachment.flag_remix() == 1 <<< 2
      assert Attachment.flag_spoiler() == 1 <<< 3
      assert Attachment.flag_animated() == 1 <<< 5
    end

    test "bit 4 is not claimed — Discord documents no flag there" do
      refute (1 <<< 4) in Enum.map(Attachment.all_flags(), &flag_value/1)
    end

    test "all_flags lists every name" do
      assert Enum.sort(Attachment.all_flags()) ==
               [:animated, :clip, :remix, :spoiler, :thumbnail]
    end
  end

  describe "has_flag?/2" do
    test "reads a struct, a raw map and a bare bitfield alike" do
      assert Attachment.has_flag?(%Attachment{flags: 8}, :spoiler)
      assert Attachment.has_flag?(%{"flags" => 8}, :spoiler)
      assert Attachment.has_flag?(8, :spoiler)
    end

    test "an attachment with no flags at all is not a crash" do
      # Discord omits `flags` entirely rather than sending 0 — seen live.
      refute Attachment.has_flag?(%Attachment{flags: nil}, :spoiler)
      refute Attachment.has_flag?(%{"filename" => "a.png"}, :spoiler)
      refute Attachment.has_flag?(nil, :spoiler)
    end

    test "an unknown flag name is false, not an error" do
      refute Attachment.has_flag?(255, :nonexistent)
    end

    test "combined flags are all reported" do
      bits = Attachment.flag_spoiler() ||| Attachment.flag_animated()

      assert Attachment.has_flag?(bits, :spoiler)
      assert Attachment.has_flag?(bits, :animated)
      refute Attachment.has_flag?(bits, :clip)
    end
  end

  describe "flag_list/1" do
    test "names the set bits and ignores the ones EDA does not know" do
      unknown = 1 <<< 20

      assert Attachment.flag_list(Attachment.flag_spoiler() ||| unknown) == [:spoiler]
    end

    test "nothing set, nothing listed" do
      assert Attachment.flag_list(0) == []
      assert Attachment.flag_list(%Attachment{flags: nil}) == []
      assert Attachment.flag_list(nil) == []
    end
  end

  describe "the named predicates" do
    test "each reads its own bit" do
      assert Attachment.spoiler?(%Attachment{flags: 1 <<< 3})
      assert Attachment.clip?(%Attachment{flags: 1 <<< 0})
      assert Attachment.thumbnail?(%Attachment{flags: 1 <<< 1})
      assert Attachment.remix?(%Attachment{flags: 1 <<< 2})
      assert Attachment.animated?(%Attachment{flags: 1 <<< 5})
    end

    test "spoiler? ignores the filename convention and trusts the flag" do
      # The SPOILER_ prefix is how a spoiler is *asked for*; the flag is what Discord
      # reports. A file merely named that way, with the flag unset, is not blurred.
      refute Attachment.spoiler?(%Attachment{filename: "SPOILER_x.png", flags: 0})
      assert Attachment.spoiler?(%Attachment{filename: "plain.png", flags: 8})
    end
  end

  describe "from_raw/1 carries the fields added for editing" do
    test "title, flags and the placeholder pair" do
      att =
        Attachment.from_raw(%{
          "id" => "1",
          "filename" => "a.png",
          "title" => "A title",
          "flags" => 8,
          "placeholder" => "abc",
          "placeholder_version" => 1
        })

      assert att.title == "A title"
      assert att.flags == 8
      assert att.placeholder == "abc"
      assert att.placeholder_version == 1
      assert Attachment.spoiler?(att)
    end
  end

  describe "keep/2" do
    test "retention alone sends nothing but the id" do
      assert Attachment.keep(%Attachment{id: "123", filename: "a.png", description: "old"}) ==
               %{id: "123"}
    end

    test "accepts a struct, a raw map, a string id and an integer id" do
      assert Attachment.keep(%Attachment{id: "1"}) == %{id: "1"}
      assert Attachment.keep(%{"id" => "1", "filename" => "a.png"}) == %{id: "1"}
      assert Attachment.keep("1") == %{id: "1"}
      assert Attachment.keep(1) == %{id: 1}
    end

    test "carries the two fields Discord lets an edit change" do
      assert Attachment.keep("1", description: "Alt", is_spoiler: true) ==
               %{id: "1", description: "Alt", is_spoiler: true}
    end

    test "is_spoiler: false is sent, because clearing the flag is a real operation" do
      # Verified live: this un-blurs an attachment that was uploaded as a spoiler.
      assert Attachment.keep("1", is_spoiler: false) == %{id: "1", is_spoiler: false}
    end

    test "an option left out is absent rather than nil, so it means 'unchanged'" do
      entry = Attachment.keep("1", description: nil, is_spoiler: nil)

      assert entry == %{id: "1"}
      refute Map.has_key?(entry, :description)
      refute Map.has_key?(entry, :is_spoiler)
    end

    test "a description over the limit is rejected before it reaches Discord" do
      assert_raise ArgumentError, ~r/exceeds 1024 characters/, fn ->
        Attachment.keep("1", description: String.duplicate("x", 1025))
      end
    end

    test "exactly at the limit is fine" do
      description = String.duplicate("x", 1024)

      assert Attachment.keep("1", description: description) == %{
               id: "1",
               description: description
             }
    end

    test "the wrong types are rejected with a message that says what was wrong" do
      assert_raise ArgumentError, ~r/must be a string/, fn ->
        Attachment.keep("1", description: :oops)
      end

      assert_raise ArgumentError, ~r/must be a boolean/, fn ->
        Attachment.keep("1", is_spoiler: "yes")
      end
    end
  end

  defp flag_value(name) do
    apply(Attachment, :"flag_#{name}", [])
  end
end
