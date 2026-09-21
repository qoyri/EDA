defmodule EDA.Voice.OggTest do
  @moduledoc """
  The OGG/Opus page parser that splits FFmpeg's output into Opus frames.

  It had no tests at all. It gained them when its bitstring patterns were changed to pin
  variables in `size(...)` for newer compilers — a change meant to be behaviour-neutral, which
  these tests were run against both before and after to confirm.
  """

  use ExUnit.Case, async: true

  alias EDA.Voice.Ogg

  # Ogg lacing: a packet is 255-byte segments followed by one shorter segment, so a packet
  # whose length is a multiple of 255 ends with a 0-byte segment.
  defp lace(packet) do
    size = byte_size(packet)
    List.duplicate(255, div(size, 255)) ++ [rem(size, 255)]
  end

  # "OggS" | version | type | granule(8) | serial(4) | sequence(4) | crc(4) | segments(1)
  defp page(packets) do
    table = Enum.flat_map(packets, &lace/1)

    <<"OggS", 0, 0, 0::64, 1::32, 0::32, 0::32, length(table)>> <>
      :binary.list_to_bin(table) <> IO.iodata_to_binary(packets)
  end

  test "splits a page into its packets" do
    assert {["abc", "defgh"], "", 0} = Ogg.extract_frames(page(["abc", "defgh"]))
  end

  test "skips the OpusHead and OpusTags header pages before the audio" do
    stream = page(["OpusHead"]) <> page(["OpusTags"]) <> page(["frame1", "frame2"])

    assert {["frame1", "frame2"], "", 0} = Ogg.extract_frames(stream, 2)
  end

  test "reassembles a packet that spans several 255-byte segments" do
    packet = :binary.copy("x", 600)
    assert lace(packet) == [255, 255, 90]

    assert {[^packet], "", 0} = Ogg.extract_frames(page([packet]))
  end

  test "a packet of exactly 255 bytes is terminated by an empty segment" do
    packet = :binary.copy("y", 255)
    assert lace(packet) == [255, 0]

    assert {[^packet], "", 0} = Ogg.extract_frames(page([packet]))
  end

  test "resynchronises on the next OggS marker after stray bytes" do
    assert {["hello"], "", 0} = Ogg.extract_frames("garbage" <> page(["hello"]))
  end

  test "reads consecutive pages" do
    stream = page(["a", "b"]) <> page(["c"])

    assert {["a", "b", "c"], "", 0} = Ogg.extract_frames(stream)
  end

  test "keeps an incomplete page for the next call instead of guessing" do
    full = page(["complete"]) <> page(["partial"])
    truncated = binary_part(full, 0, byte_size(full) - 3)

    {frames, rest, 0} = Ogg.extract_frames(truncated)

    assert frames == ["complete"]
    # the half page is handed back whole, to be completed by the next chunk
    assert rest == binary_part(page(["partial"]), 0, byte_size(page(["partial"])) - 3)
    assert {["partial"], "", 0} = Ogg.extract_frames(rest <> "ial")
  end

  test "a buffer shorter than a page header is incomplete" do
    assert {[], "OggS", 0} = Ogg.extract_frames("OggS")
  end

  test "the header skip count survives an incomplete buffer" do
    assert {[], "", 2} = Ogg.extract_frames("", 2)
  end
end
