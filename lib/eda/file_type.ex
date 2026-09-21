defmodule EDA.FileType do
  @moduledoc """
  The file type filters Discord shows the user when picking a file.

  An `ATTACHMENT` command option — and, once it exists, the File Upload component — takes up
  to ten filters. Each is one of the group names `image`, `video` or `audio`, or a
  dot-prefixed extension such as `.pdf`.

      import EDA.Command.Option

      attachment("receipt", "Your receipt", required: true, file_types: [:image, ".pdf"])

  > #### This is not validation {: .error}
  >
  > Discord matches the **filename's extension** and never looks inside the file. Renaming
  > `payload.exe` to `payload.png` passes the filter. Discord says so outright: "You are
  > still responsible for validating the actual contents of the file."
  >
  > Treat it as a convenience that narrows the file picker, and check the bytes yourself when
  > it matters — `EDA.ImageData.type/1` does that for images.

  ## Discord reorders them

  A registered command does not read back in the order it was sent: `["image", ".pdf"]`
  comes back as `[".pdf", "image"]`. Comparing the two lists directly — when diffing a
  deployed command against its definition to decide whether to re-register — therefore says
  "changed" forever. Compare `expand/1` of each instead, which is sorted and deduplicated.

  ## Checking a file yourself

  `expand/1` turns the filters into the concrete extensions Discord would have allowed, and
  `matches?/2` answers whether a filename is one of them — for re-checking an upload against
  the same rule the picker used.

      iex> EDA.FileType.matches?("holiday.JPG", [:image])
      true

      iex> EDA.FileType.matches?("notes.txt", [:image, ".pdf"])
      false
  """

  @groups %{
    image: ~w(.png .gif .jpg .jpeg .jfif .webp .avif),
    video: ~w(.mp4 .mov .qt .webm),
    audio: ~w(.mp3 .m4a .wav .ogg .opus .flac)
  }

  @max_filters 10

  @typedoc "A group name, or a dot-prefixed extension such as `\".pdf\"`."
  @type filter :: :image | :video | :audio | String.t()

  @doc """
  The group names Discord accepts, and the extensions each stands for.

  ## Examples

      iex> EDA.FileType.groups()[:video]
      [".mp4", ".mov", ".qt", ".webm"]
  """
  @spec groups() :: %{atom() => [String.t()]}
  def groups, do: @groups

  @doc "The most filters Discord accepts on one option."
  @spec max_filters() :: pos_integer()
  def max_filters, do: @max_filters

  @doc """
  Validates a list of filters and returns what should go on the wire.

  Group names may be given as atoms or strings; extensions are lowercased, since Discord
  treats `.PDF` and `.pdf` alike.

  Raises `ArgumentError` for more than #{@max_filters} filters, for a name that is not a
  group, or for an extension written without its dot — `"pdf"` is not a group Discord knows
  and would silently filter nothing.

  ## Examples

      iex> EDA.FileType.normalize!([:image, ".PDF"])
      ["image", ".pdf"]

      iex> EDA.FileType.normalize!(["audio"])
      ["audio"]
  """
  @spec normalize!([filter()]) :: [String.t()]
  def normalize!(filters) when is_list(filters) do
    if length(filters) > @max_filters do
      raise ArgumentError,
            "at most #{@max_filters} file types are allowed, got #{length(filters)}"
    end

    Enum.map(filters, &normalize_one!/1)
  end

  def normalize!(other) do
    raise ArgumentError, ":file_types must be a list, got: #{inspect(other)}"
  end

  defp normalize_one!(name) when is_atom(name) and not is_nil(name) do
    if Map.has_key?(@groups, name) do
      Atom.to_string(name)
    else
      raise ArgumentError, bad_filter_message(name)
    end
  end

  defp normalize_one!(value) when is_binary(value) do
    downcased = String.downcase(value)

    cond do
      Map.has_key?(@groups, safe_group(downcased)) -> downcased
      String.starts_with?(downcased, ".") and byte_size(downcased) > 1 -> downcased
      true -> raise ArgumentError, bad_filter_message(value)
    end
  end

  defp normalize_one!(other), do: raise(ArgumentError, bad_filter_message(other))

  # String.to_existing_atom/1 raises for arbitrary user input, so match on the known names.
  defp safe_group("image"), do: :image
  defp safe_group("video"), do: :video
  defp safe_group("audio"), do: :audio
  defp safe_group(_other), do: nil

  defp bad_filter_message(value) do
    "invalid file type #{inspect(value)}: expected one of #{inspect(Map.keys(@groups))} " <>
      "or a dot-prefixed extension such as \".pdf\""
  end

  @doc """
  Expands filters into the extensions Discord would accept, lowercased and deduplicated.

  ## Examples

      iex> EDA.FileType.expand([:audio])
      [".flac", ".m4a", ".mp3", ".ogg", ".opus", ".wav"]

      iex> EDA.FileType.expand([".PDF", ".pdf"])
      [".pdf"]

      iex> EDA.FileType.expand([])
      []
  """
  @spec expand([filter()]) :: [String.t()]
  def expand(filters) when is_list(filters) do
    filters
    |> normalize!()
    |> Enum.flat_map(fn filter ->
      case safe_group(filter) do
        nil -> [filter]
        group -> @groups[group]
      end
    end)
    |> Enum.uniq()
    |> Enum.sort()
  end

  @doc """
  Returns `true` if two filter lists mean the same thing.

  Order-insensitive and duplicate-insensitive, because Discord returns filters in an order
  of its own. This is the comparison to use when deciding whether a registered command still
  matches its definition.

  ## Examples

      iex> EDA.FileType.equivalent?(["image", ".pdf"], [".pdf", :image])
      true

      iex> EDA.FileType.equivalent?([:image], [:image, ".pdf"])
      false
  """
  @spec equivalent?([filter()], [filter()]) :: boolean()
  def equivalent?(left, right) when is_list(left) and is_list(right),
    do: expand(left) == expand(right)

  @doc """
  Returns `true` if a filename passes the filters.

  Compares the extension only, case-insensitively — the same shallow check Discord makes, so
  this re-applies the picker's rule rather than adding one. An empty filter list accepts
  everything, which is what an option without `:file_types` means.

  Remember that a matching extension says nothing about the contents.

  ## Examples

      iex> EDA.FileType.matches?("clip.MP4", [:video])
      true

      iex> EDA.FileType.matches?("report.pdf", [:image, ".pdf"])
      true

      iex> EDA.FileType.matches?("README", [:image])
      false

      iex> EDA.FileType.matches?("anything.xyz", [])
      true
  """
  @spec matches?(String.t(), [filter()]) :: boolean()
  def matches?(_filename, []), do: true

  def matches?(filename, filters) when is_binary(filename) and is_list(filters) do
    extension = filename |> Path.extname() |> String.downcase()

    extension != "" and extension in expand(filters)
  end
end
