defmodule EDA.MarkdownTest do
  use ExUnit.Case, async: true

  doctest EDA.Markdown
  doctest EDA.Mention, only: [slash_command: 2, message_link: 3]

  test "split/2 never exceeds the limit and loses nothing but the break it split at" do
    text = Enum.map_join(1..300, "\n", &("line #{&1} " <> String.duplicate("x", rem(&1, 40))))
    parts = EDA.Markdown.split(text)

    assert Enum.all?(parts, &(String.length(&1) <= 2000))
    assert Enum.join(parts, "\n") == text
  end

  test "a line longer than the limit splits at its words, keeping the line break after it" do
    text = String.duplicate("word ", 10) <> "end\nnext line"
    parts = EDA.Markdown.split(text, 20)

    assert Enum.all?(parts, &(String.length(&1) <= 20))
    assert List.last(parts) =~ "next line"
  end

  test "escape/1 leaves mentions and plain text alone" do
    assert EDA.Markdown.escape("<@123> said hi") == "<@123> said hi"
  end
end
