defmodule EDA.Voice.Ogg do
  @moduledoc """
  OGG page parser for extracting Opus frames from an OGG/Opus stream.

  When FFmpeg outputs with `-f ogg`, audio data is wrapped in OGG pages
  with proper frame boundaries. This module parses those pages to extract
  individual Opus frames, solving the frame merging issue that occurs with
  raw `-f data` output where Erlang's port `:stream` mode can concatenate
  multiple frames into a single message.
  """

  @ogg_marker "OggS"
  @min_header_size 27

  @doc """
  Extracts opus frames from a buffer of OGG data.

  Returns `{frames, remaining_buffer, headers_to_skip}` where:
  - `frames` is a list of individual opus frame binaries
  - `remaining_buffer` is leftover data awaiting more input
  - `headers_to_skip` is the updated count of header pages still to skip

  A new OGG/Opus stream has 2 header pages (OpusHead, OpusTags) that must
  be skipped before audio data begins.
  """
  @spec extract_frames(binary(), non_neg_integer()) :: {[binary()], binary(), non_neg_integer()}
  def extract_frames(buffer, headers_to_skip \\ 0) do
    do_extract(buffer, headers_to_skip, [])
  end

  defp do_extract(buffer, skip, acc) do
    case parse_page(buffer) do
      {:ok, segment_table, page_data, rest} ->
        if skip > 0 do
          do_extract(rest, skip - 1, acc)
        else
          packets = extract_packets(segment_table, page_data)
          do_extract(rest, 0, acc ++ packets)
        end

      :incomplete ->
        {acc, buffer, skip}
    end
  end

  # Parse a single OGG page from the buffer.
  # OGG page header (27 bytes):
  #   "OggS" (4) | version (1) | type (1) | granule (8) | serial (4)
  #   | page_seq (4) | crc (4) | num_segments (1)
  # Followed by: segment_table (num_segments bytes) | segment_data (sum of table)
  defp parse_page(buffer) when byte_size(buffer) < @min_header_size, do: :incomplete

  defp parse_page(
         <<@ogg_marker, _ver, _type, _granule::binary-8, _serial::binary-4, _page_seq::binary-4,
           _crc::binary-4, num_segments, rest::binary>>
       ) do
    if byte_size(rest) < num_segments do
      :incomplete
    else
      <<seg_table::binary-size(num_segments), after_table::binary>> = rest
      data_size = seg_table |> :binary.bin_to_list() |> Enum.sum()

      if byte_size(after_table) < data_size do
        :incomplete
      else
        <<page_data::binary-size(data_size), remaining::binary>> = after_table
        {:ok, seg_table, page_data, remaining}
      end
    end
  end

  defp parse_page(buffer) do
    # Buffer doesn't start with OggS — try to resync
    case :binary.match(buffer, @ogg_marker) do
      {pos, 4} when pos > 0 ->
        <<_skip::binary-size(pos), aligned::binary>> = buffer
        parse_page(aligned)

      _ ->
        :incomplete
    end
  end

  # Extract individual opus packets from OGG page segments.
  # In OGG, a segment of exactly 255 bytes means the packet continues
  # in the next segment. A segment < 255 bytes terminates the packet.
  defp extract_packets(segment_table, data) do
    segments = :binary.bin_to_list(segment_table)
    do_extract_packets(segments, data, <<>>, [])
  end

  defp do_extract_packets([], _data, <<>>, acc), do: Enum.reverse(acc)
  defp do_extract_packets([], _data, current, acc), do: Enum.reverse([current | acc])

  defp do_extract_packets([size | rest], data, current, acc) do
    <<segment::binary-size(size), remaining::binary>> = data
    combined = <<current::binary, segment::binary>>

    if size < 255 do
      if byte_size(combined) > 0 do
        do_extract_packets(rest, remaining, <<>>, [combined | acc])
      else
        do_extract_packets(rest, remaining, <<>>, acc)
      end
    else
      # Continuation — packet spans multiple segments
      do_extract_packets(rest, remaining, combined, acc)
    end
  end
end
