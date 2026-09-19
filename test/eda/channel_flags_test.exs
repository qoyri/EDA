defmodule EDA.ChannelFlagsTest do
  use ExUnit.Case, async: true

  import Bitwise

  alias EDA.Channel

  # Nothing ran EDA.Channel's documented examples before; this verifies them.
  doctest EDA.Channel

  describe "flag constants match Discord's documented values" do
    test "the documented bit positions" do
      assert Channel.flag_pinned() == 1 <<< 1
      assert Channel.flag_require_tag() == 1 <<< 4
      assert Channel.flag_hide_media_download_options() == 1 <<< 15
      assert Channel.flag_obfuscated() == 1 <<< 17
      assert Channel.flag_spoiler() == 1 <<< 21
    end

    test "all_flags/0 lists every known name" do
      assert Enum.sort(Channel.all_flags()) == [
               :hide_media_download_options,
               :obfuscated,
               :pinned,
               :require_tag,
               :spoiler
             ]
    end

    test "obfuscated_name/0 is the string Discord substitutes" do
      assert Channel.obfuscated_name() == "___hidden___"
    end
  end

  describe "has_flag?/2" do
    test "reads a struct" do
      assert Channel.has_flag?(%Channel{flags: 1 <<< 17}, :obfuscated)
      refute Channel.has_flag?(%Channel{flags: 1 <<< 17}, :pinned)
    end

    test "reads a raw cache map (string keys)" do
      assert Channel.has_flag?(%{"flags" => 1 <<< 1}, :pinned)
      refute Channel.has_flag?(%{"flags" => 0}, :obfuscated)
    end

    test "reads a bare bitfield" do
      assert Channel.has_flag?(1 <<< 21, :spoiler)
    end

    test "is false for nil flags, a nil channel, and an unknown flag" do
      refute Channel.has_flag?(%Channel{flags: nil}, :obfuscated)
      refute Channel.has_flag?(nil, :obfuscated)
      refute Channel.has_flag?(%{}, :obfuscated)
      refute Channel.has_flag?(0xFFFFFF, :not_a_flag)
    end

    test "distinguishes bits that are numerically close" do
      # 1 <<< 15 is HIDE_MEDIA_DOWNLOAD_OPTIONS, not obfuscation
      refute Channel.has_flag?(1 <<< 15, :obfuscated)
      assert Channel.has_flag?(1 <<< 15, :hide_media_download_options)
    end
  end

  describe "flag_list/1" do
    test "returns set flags, sorted" do
      assert Channel.flag_list(%Channel{flags: (1 <<< 17) + (1 <<< 1)}) == [:obfuscated, :pinned]
    end

    test "ignores bits EDA does not know about" do
      assert Channel.flag_list(1 <<< 30) == []
      assert Channel.flag_list((1 <<< 30) + (1 <<< 17)) == [:obfuscated]
    end

    test "is empty for nil and for a channel without flags" do
      assert Channel.flag_list(nil) == []
      assert Channel.flag_list(%Channel{flags: nil}) == []
      assert Channel.flag_list(%{}) == []
    end
  end

  describe "obfuscated?/1" do
    test "true only when the obfuscation bit is set" do
      assert Channel.obfuscated?(%Channel{flags: 1 <<< 17})
      refute Channel.obfuscated?(%Channel{flags: 0})
      refute Channel.obfuscated?(%Channel{flags: nil})
    end

    test "works on the raw maps the cache stores" do
      assert Channel.obfuscated?(%{"flags" => 1 <<< 17})
      refute Channel.obfuscated?(%{"flags" => 1 <<< 15})
    end

    test "survives a channel parsed from a redacted gateway payload" do
      raw = %{
        "id" => "123",
        "name" => Channel.obfuscated_name(),
        "type" => 0,
        "flags" => 1 <<< 17,
        "permission_overwrites" => [
          %{"id" => "456", "type" => 0, "allow" => "0", "deny" => "1024"}
        ]
      }

      channel = Channel.from_raw(raw)

      assert Channel.obfuscated?(channel)
      assert channel.name == "___hidden___"
      assert :obfuscated in Channel.flag_list(channel)
    end

    test "is false for nil" do
      refute Channel.obfuscated?(nil)
    end
  end
end
