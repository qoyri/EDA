defmodule EDA.Markdown do
  @moduledoc """
  Discord's markdown: escaping user text so it shows as typed, the styles, code, quotes,
  headers, lists and masked links, and splitting a long text into messages.

      import EDA.Markdown

      bold("Warning") <> " " <> escape(user_input)
      code_block(output, "elixir")
      for part <- split(long_text), do: EDA.Channel.send_message(channel, part)
  """

  @inline ~r/([\\*_~`|\[\]])/
  @line_start ~r/^(\s*)([>#-])/m

  @doc ~S"""
  Escapes markdown in text so it shows as typed: `*`, `_`, `~`, `` ` ``, `|` and brackets
  anywhere, and `>`, `#` and `-` where they start a line (a quote, a header, a list). Mentions
  and links are left alone.

      iex> EDA.Markdown.escape("*not bold* and __not underlined__")
      "\\*not bold\\* and \\_\\_not underlined\\_\\_"
      iex> EDA.Markdown.escape("# not a header, <@1> stays")
      "\\# not a header, <@1> stays"
  """
  @spec escape(String.t()) :: String.t()
  def escape(text) when is_binary(text) do
    text
    |> then(&Regex.replace(@inline, &1, "\\\\\\1"))
    |> then(&Regex.replace(@line_start, &1, "\\1\\\\\\2"))
  end

  @doc ~S"""
  Bold.

      iex> EDA.Markdown.bold("hi")
      "**hi**"
  """
  @spec bold(String.t()) :: String.t()
  def bold(text), do: "**#{text}**"

  @doc ~S"Italic: `*text*`."
  @spec italic(String.t()) :: String.t()
  def italic(text), do: "*#{text}*"

  @doc ~S"Underlined: `__text__`."
  @spec underline(String.t()) :: String.t()
  def underline(text), do: "__#{text}__"

  @doc ~S"Struck through: `~~text~~`."
  @spec strikethrough(String.t()) :: String.t()
  def strikethrough(text), do: "~~#{text}~~"

  @doc ~S"Hidden until clicked: `||text||`."
  @spec spoiler(String.t()) :: String.t()
  def spoiler(text), do: "||#{text}||"

  @doc ~S"""
  Inline code. Text holding backticks is fenced with enough of them to stay intact.

      iex> EDA.Markdown.code("x = 1")
      "`x = 1`"
      iex> EDA.Markdown.code("a`b")
      "`` a`b ``"
  """
  @spec code(String.t()) :: String.t()
  def code(text) do
    if String.contains?(text, "`"), do: "`` #{text} ``", else: "`#{text}`"
  end

  @doc ~S"""
  A code block, with an optional language for highlighting. Triple backticks inside the code
  are broken with a zero-width space so they do not end the block.

      iex> EDA.Markdown.code_block("IO.puts(1)", "elixir")
      "```elixir\nIO.puts(1)\n```"
  """
  @spec code_block(String.t(), String.t() | nil) :: String.t()
  def code_block(text, language \\ nil),
    do: "```#{language}\n#{String.replace(text, "```", "`\u200B``")}\n```"

  @doc ~S"""
  A quote: each line prefixed with `> `.

      iex> EDA.Markdown.quote_text("a\nb")
      "> a\n> b"
  """
  @spec quote_text(String.t()) :: String.t()
  def quote_text(text), do: text |> String.split("\n") |> Enum.map_join("\n", &("> " <> &1))

  @doc ~S"A block quote: `>>> ` before the text, which quotes it to the end of the message."
  @spec block_quote(String.t()) :: String.t()
  def block_quote(text), do: ">>> " <> text

  @doc ~S"""
  A header, level 1 to 3.

      iex> EDA.Markdown.header("Rules", 2)
      "## Rules"
  """
  @spec header(String.t(), 1..3) :: String.t()
  def header(text, level \\ 1) when level in 1..3, do: String.duplicate("#", level) <> " " <> text

  @doc ~S"Small grey text under a message: `-# text`."
  @spec subtext(String.t()) :: String.t()
  def subtext(text), do: "-# " <> text

  @doc ~S"""
  A link shown as `text`, with an optional hover title. `embed: false` wraps the URL in angle
  brackets, so Discord does not preview it.

      iex> EDA.Markdown.masked_link("docs", "https://hexdocs.pm/eda")
      "[docs](https://hexdocs.pm/eda)"
      iex> EDA.Markdown.masked_link("docs", "https://hexdocs.pm/eda", title: "EDA", embed: false)
      "[docs](<https://hexdocs.pm/eda> \"EDA\")"
  """
  @spec masked_link(String.t(), String.t(), keyword()) :: String.t()
  def masked_link(text, url, opts \\ []) do
    url = if Keyword.get(opts, :embed, true), do: url, else: "<#{url}>"
    title = if opts[:title], do: ~s( "#{opts[:title]}"), else: ""
    "[#{text}](#{url}#{title})"
  end

  @doc ~S"""
  A bulleted list, or a numbered one with `ordered: true`.

      iex> EDA.Markdown.list(["a", "b"])
      "- a\n- b"
      iex> EDA.Markdown.list(["a", "b"], ordered: true)
      "1. a\n2. b"
  """
  @spec list([String.t()], keyword()) :: String.t()
  def list(items, opts \\ []) do
    if opts[:ordered] do
      items |> Enum.with_index(1) |> Enum.map_join("\n", fn {item, i} -> "#{i}. #{item}" end)
    else
      Enum.map_join(items, "\n", &("- " <> &1))
    end
  end

  @doc ~S"""
  Splits text into parts of at most `max` characters (2000, a message's limit), at line breaks
  when it can, then at spaces, and only then within a word.

      iex> EDA.Markdown.split("aaa bbb\nccc", 7)
      ["aaa bbb", "ccc"]
      iex> EDA.Markdown.split("abcdefghij", 4)
      ["abcd", "efgh", "ij"]
  """
  @spec split(String.t(), pos_integer()) :: [String.t()]
  def split(text, max \\ 2000) when is_binary(text) and max > 0 do
    text
    |> pieces(max)
    |> pack(max)
  end

  # The text as pieces no longer than max, each ending where a break was: lines first, then
  # words, then characters.
  defp pieces(text, max) do
    text
    |> String.split("\n")
    |> Enum.flat_map(fn line ->
      if String.length(line) <= max, do: [{line, "\n"}], else: words(line, max)
    end)
  end

  # A line too long to keep whole, as words; a word too long, in chunks. Each piece carries the
  # separator that followed it, so the last one ends the line.
  defp words(line, max) do
    words = String.split(line, " ")
    last = length(words) - 1

    words
    |> Enum.with_index()
    |> Enum.flat_map(fn {word, i} ->
      sep = if i == last, do: "\n", else: " "

      if String.length(word) <= max do
        [{word, sep}]
      else
        chunks = word |> String.graphemes() |> Enum.chunk_every(max) |> Enum.map(&Enum.join/1)
        {init, [tail]} = Enum.split(chunks, -1)
        Enum.map(init, &{&1, ""}) ++ [{tail, sep}]
      end
    end)
  end

  # Joins the pieces greedily into parts of at most max.
  defp pack(pieces, max) do
    {parts, current} = Enum.reduce(pieces, {[], nil}, &add_piece(&1, &2, max))
    parts = if current, do: [elem(current, 0) | parts], else: parts
    parts |> Enum.reverse() |> Enum.reject(&(&1 == ""))
  end

  defp add_piece({piece, sep}, {parts, nil}, _max), do: {parts, {piece, sep}}

  defp add_piece({piece, sep}, {parts, {text, last_sep}}, max) do
    joined = text <> last_sep <> piece

    if String.length(joined) <= max,
      do: {parts, {joined, sep}},
      else: {[text | parts], {piece, sep}}
  end
end
