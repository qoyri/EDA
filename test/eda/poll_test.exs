defmodule EDA.PollTest do
  use ExUnit.Case, async: true

  alias EDA.Poll
  alias EDA.Poll.{Answer, AnswerCount}

  # ── from_raw/1 ──────────────────────────────────────────────────────

  describe "from_raw/1" do
    test "parses a complete poll" do
      raw = %{
        "question" => %{"text" => "Best language?"},
        "answers" => [
          %{"answer_id" => 1, "poll_media" => %{"text" => "Elixir"}},
          %{"answer_id" => 2, "poll_media" => %{"text" => "Rust"}}
        ],
        "expiry" => "2025-06-01T00:00:00+00:00",
        "allow_multiselect" => true,
        "layout_type" => 1,
        "results" => %{
          "is_finalized" => true,
          "answer_counts" => [
            %{"id" => 1, "count" => 10, "me_voted" => false},
            %{"id" => 2, "count" => 5, "me_voted" => true}
          ]
        }
      }

      poll = Poll.from_raw(raw)
      assert poll.question == "Best language?"
      assert length(poll.answers) == 2
      assert poll.expiry == ~U[2025-06-01 00:00:00Z]
      assert poll.allow_multiselect == true
      assert poll.layout_type == 1

      assert {true, [%AnswerCount{id: 1, count: 10}, %AnswerCount{id: 2, count: 5}]} =
               poll.results
    end

    test "parses without results" do
      raw = %{
        "question" => %{"text" => "Test?"},
        "answers" => [],
        "allow_multiselect" => false,
        "layout_type" => 1
      }

      poll = Poll.from_raw(raw)
      assert poll.results == nil
    end

    test "parses results with finalized but no answer_counts" do
      raw = %{
        "question" => %{"text" => "Test?"},
        "answers" => [],
        "results" => %{"is_finalized" => false}
      }

      poll = Poll.from_raw(raw)
      assert poll.results == {false, []}
    end
  end

  # ── to_raw/1 ────────────────────────────────────────────────────────

  describe "to_raw/1" do
    test "serializes for creation" do
      poll = %Poll{
        question: "Pick one",
        answers: [%Answer{text: "A"}, %Answer{text: "B"}],
        duration: 24,
        allow_multiselect: false,
        layout_type: 1
      }

      raw = Poll.to_raw(poll)
      assert raw["question"] == %{"text" => "Pick one"}
      assert length(raw["answers"]) == 2
      assert raw["duration"] == 24
      assert raw["allow_multiselect"] == false
      assert raw["layout_type"] == 1
    end
  end

  # ── new/2 ───────────────────────────────────────────────────────────

  describe "new/2" do
    test "creates with defaults" do
      poll = Poll.new("Favorite color?")
      assert poll.question == "Favorite color?"
      assert poll.duration == 24
      assert poll.allow_multiselect == false
      assert poll.layout_type == 1
      assert poll.answers == []
    end

    test "creates with custom options" do
      poll = Poll.new("Pick many", duration: 48, multiselect: true, layout: 1)
      assert poll.duration == 48
      assert poll.allow_multiselect == true
    end

    test "raises on question too long" do
      long = String.duplicate("a", 301)

      assert_raise ArgumentError, ~r/question must be at most 300/, fn ->
        Poll.new(long)
      end
    end

    test "raises on invalid duration" do
      assert_raise ArgumentError, ~r/duration must be between/, fn ->
        Poll.new("Test?", duration: 0)
      end

      assert_raise ArgumentError, ~r/duration must be between/, fn ->
        Poll.new("Test?", duration: 769)
      end
    end
  end

  # ── add_answer/3 ────────────────────────────────────────────────────

  describe "add_answer/3" do
    test "adds a basic answer" do
      poll = Poll.new("Test?") |> Poll.add_answer("Option A")
      assert length(poll.answers) == 1
      assert hd(poll.answers).text == "Option A"
    end

    test "adds answer with unicode emoji string" do
      poll = Poll.new("Test?") |> Poll.add_answer("Fire", emoji: "🔥")
      answer = hd(poll.answers)
      assert %EDA.Emoji{name: "🔥"} = answer.emoji
    end

    test "adds answer with Emoji struct" do
      emoji = %EDA.Emoji{id: "123", name: "cool"}
      poll = Poll.new("Test?") |> Poll.add_answer("Cool", emoji: emoji)
      answer = hd(poll.answers)
      assert answer.emoji.id == "123"
      assert answer.emoji.name == "cool"
    end

    test "raises at 11th answer" do
      poll =
        Enum.reduce(1..10, Poll.new("Test?"), fn i, acc ->
          Poll.add_answer(acc, "Option #{i}")
        end)

      assert length(poll.answers) == 10

      assert_raise ArgumentError, ~r/more than 10/, fn ->
        Poll.add_answer(poll, "Too many")
      end
    end

    test "raises on answer text too long" do
      long = String.duplicate("a", 56)

      assert_raise ArgumentError, ~r/answer text must be at most 55/, fn ->
        Poll.new("Test?") |> Poll.add_answer(long)
      end
    end
  end

  # ── expired?/1 ──────────────────────────────────────────────────────

  describe "expired?/1" do
    test "returns true for past expiry" do
      poll = %Poll{expiry: "2020-01-01T00:00:00+00:00"}
      assert Poll.expired?(poll) == true
    end

    test "returns false for nil expiry" do
      poll = %Poll{expiry: nil}
      assert Poll.expired?(poll) == false
    end
  end

  # ── finalized?/1 ────────────────────────────────────────────────────

  describe "finalized?/1" do
    test "returns true when results are finalized" do
      poll = %Poll{results: {true, []}}
      assert Poll.finalized?(poll) == true
    end

    test "returns false when results are not finalized" do
      poll = %Poll{results: {false, []}}
      assert Poll.finalized?(poll) == false
    end

    test "returns false when no results" do
      poll = %Poll{results: nil}
      assert Poll.finalized?(poll) == false
    end
  end

  # ── total_votes/1 ───────────────────────────────────────────────────

  describe "total_votes/1" do
    test "sums all counts" do
      counts = [
        %AnswerCount{id: 1, count: 5, me_voted: false},
        %AnswerCount{id: 2, count: 3, me_voted: true}
      ]

      poll = %Poll{results: {true, counts}}
      assert Poll.total_votes(poll) == 8
    end

    test "returns 0 when no results" do
      poll = %Poll{results: nil}
      assert Poll.total_votes(poll) == 0
    end
  end

  # ── winning_answer/1 ────────────────────────────────────────────────

  describe "winning_answer/1" do
    test "returns answer with most votes" do
      answers = [
        %Answer{answer_id: 1, text: "A"},
        %Answer{answer_id: 2, text: "B"}
      ]

      counts = [
        %AnswerCount{id: 1, count: 3, me_voted: false},
        %AnswerCount{id: 2, count: 7, me_voted: false}
      ]

      poll = %Poll{answers: answers, results: {true, counts}}
      assert %Answer{answer_id: 2, text: "B"} = Poll.winning_answer(poll)
    end

    test "returns nil when no results" do
      poll = %Poll{results: nil}
      assert Poll.winning_answer(poll) == nil
    end

    test "returns nil when results have empty counts" do
      poll = %Poll{answers: [], results: {true, []}}
      assert Poll.winning_answer(poll) == nil
    end
  end

  # ── Constants ───────────────────────────────────────────────────────

  describe "constants" do
    test "layout_default is 1" do
      assert Poll.layout_default() == 1
    end

    test "max_answers is 10" do
      assert Poll.max_answers() == 10
    end

    test "max_question_length is 300" do
      assert Poll.max_question_length() == 300
    end

    test "max_answer_length is 55" do
      assert Poll.max_answer_length() == 55
    end

    test "min_duration is 1" do
      assert Poll.min_duration() == 1
    end

    test "max_duration is 768" do
      assert Poll.max_duration() == 768
    end
  end
end
