defmodule EDA.Poll do
  @moduledoc """
  Represents a Discord message poll.

  Combines a data struct (received from the gateway), a pipe-friendly builder
  (for creating polls), and query helpers (for analyzing results).

  ## Building a poll

      import EDA.Poll

      poll =
        new("What's your favorite color?", duration: 48, multiselect: true)
        |> add_answer("Red", emoji: "🔴")
        |> add_answer("Blue", emoji: "🔵")
        |> add_answer("Green", emoji: "🟢")

      EDA.API.Message.create(channel_id, poll: poll)

  ## Analyzing results

      poll = message.poll

      EDA.Poll.expired?(poll)
      EDA.Poll.finalized?(poll)
      EDA.Poll.total_votes(poll)
      EDA.Poll.winning_answer(poll)
  """

  use EDA.Event.Access

  alias EDA.Poll.{Answer, AnswerCount}

  defstruct [
    :question,
    :expiry,
    :duration,
    :layout_type,
    :results,
    allow_multiselect: false,
    answers: []
  ]

  @type t :: %__MODULE__{
          question: String.t() | nil,
          answers: [Answer.t()],
          expiry: DateTime.t() | nil,
          duration: integer() | nil,
          allow_multiselect: boolean(),
          layout_type: integer() | nil,
          results: {boolean(), [AnswerCount.t()]} | nil
        }

  # ── Constants ────────────────────────────────────────────────────────

  @layout_default 1

  @max_question_length 300
  @max_answer_length 55
  @max_answers 10
  @min_duration 1
  @max_duration 768

  @doc "Returns the default layout type (1)."
  @spec layout_default() :: integer()
  def layout_default, do: @layout_default

  @doc "Returns the maximum question length (300)."
  @spec max_question_length() :: integer()
  def max_question_length, do: @max_question_length

  @doc "Returns the maximum answer text length (55)."
  @spec max_answer_length() :: integer()
  def max_answer_length, do: @max_answer_length

  @doc "Returns the maximum number of answers (10)."
  @spec max_answers() :: integer()
  def max_answers, do: @max_answers

  @doc "Returns the minimum poll duration in hours (1)."
  @spec min_duration() :: integer()
  def min_duration, do: @min_duration

  @doc "Returns the maximum poll duration in hours (768)."
  @spec max_duration() :: integer()
  def max_duration, do: @max_duration

  # ── Parsing ──────────────────────────────────────────────────────────

  @doc """
  Parses a poll from a raw Discord API map.

  ## Examples

      iex> raw = %{
      ...>   "question" => %{"text" => "Best language?"},
      ...>   "answers" => [%{"answer_id" => 1, "poll_media" => %{"text" => "Elixir"}}],
      ...>   "expiry" => "2025-01-01T00:00:00+00:00",
      ...>   "allow_multiselect" => false,
      ...>   "layout_type" => 1,
      ...>   "results" => %{
      ...>     "is_finalized" => true,
      ...>     "answer_counts" => [%{"id" => 1, "count" => 10, "me_voted" => false}]
      ...>   }
      ...> }
      iex> poll = EDA.Poll.from_raw(raw)
      iex> poll.question
      "Best language?"
      iex> poll.results
      {true, [%EDA.Poll.AnswerCount{id: 1, count: 10, me_voted: false}]}
  """
  @spec from_raw(map()) :: t()
  def from_raw(raw) when is_map(raw) do
    %__MODULE__{
      question: get_in(raw, ["question", "text"]),
      answers: parse_answers(raw["answers"]),
      expiry: EDA.Timestamp.parse(raw["expiry"]),
      duration: raw["duration"],
      allow_multiselect: raw["allow_multiselect"] || false,
      layout_type: raw["layout_type"],
      results: parse_results(raw["results"])
    }
  end

  @doc """
  Serializes a poll to the Discord API format for message creation.

  ## Examples

      iex> poll = %EDA.Poll{question: "Yes?", answers: [%EDA.Poll.Answer{text: "Yes"}], duration: 24, allow_multiselect: false, layout_type: 1}
      iex> raw = EDA.Poll.to_raw(poll)
      iex> raw["question"]
      %{"text" => "Yes?"}
  """
  @spec to_raw(t()) :: map()
  def to_raw(%__MODULE__{} = poll) do
    raw = %{
      "question" => %{"text" => poll.question},
      "answers" => Enum.map(poll.answers, &Answer.to_raw/1),
      "allow_multiselect" => poll.allow_multiselect
    }

    raw = if poll.duration, do: Map.put(raw, "duration", poll.duration), else: raw
    raw = if poll.layout_type, do: Map.put(raw, "layout_type", poll.layout_type), else: raw
    raw
  end

  # ── Builder ──────────────────────────────────────────────────────────

  @doc """
  Creates a new poll with the given question.

  ## Options

    * `:duration` - Duration in hours (1-768, default: 24)
    * `:multiselect` - Allow multiple votes (default: false)
    * `:layout` - Layout type (default: 1)

  ## Examples

      iex> poll = EDA.Poll.new("Favorite color?")
      iex> poll.question
      "Favorite color?"
      iex> poll.duration
      24

      iex> poll = EDA.Poll.new("Pick many", duration: 48, multiselect: true)
      iex> poll.duration
      48
      iex> poll.allow_multiselect
      true
  """
  @spec new(String.t(), keyword()) :: t()
  def new(question, opts \\ []) when is_binary(question) do
    validate_length!(question, @max_question_length, "question")

    duration = Keyword.get(opts, :duration, 24)
    validate_duration!(duration)

    %__MODULE__{
      question: question,
      answers: [],
      duration: duration,
      allow_multiselect: Keyword.get(opts, :multiselect, false),
      layout_type: Keyword.get(opts, :layout, @layout_default)
    }
  end

  @doc """
  Adds an answer to the poll (max 10 answers).

  ## Options

    * `:emoji` - An `EDA.Emoji` struct or a unicode string (e.g. `"🔴"`)

  ## Examples

      iex> poll = EDA.Poll.new("Test?") |> EDA.Poll.add_answer("Option A")
      iex> length(poll.answers)
      1

      iex> poll = EDA.Poll.new("Test?") |> EDA.Poll.add_answer("Fire", emoji: "🔥")
      iex> hd(poll.answers).emoji
      %EDA.Emoji{name: "🔥"}
  """
  @spec add_answer(t(), String.t(), keyword()) :: t()
  def add_answer(%__MODULE__{} = poll, text, opts \\ []) when is_binary(text) do
    if length(poll.answers) >= @max_answers do
      raise ArgumentError, "poll cannot have more than #{@max_answers} answers"
    end

    validate_length!(text, @max_answer_length, "answer text")

    emoji = resolve_answer_emoji(opts[:emoji])
    answer = %Answer{text: text, emoji: emoji}

    %{poll | answers: poll.answers ++ [answer]}
  end

  # ── Query helpers ────────────────────────────────────────────────────

  @doc """
  Returns `true` if the poll has expired.

  Compares the `expiry` timestamp against `DateTime.utc_now/0`.
  Returns `false` if `expiry` is nil.

  ## Examples

      iex> EDA.Poll.expired?(%EDA.Poll{expiry: ~U[2020-01-01 00:00:00Z]})
      true

      iex> EDA.Poll.expired?(%EDA.Poll{expiry: nil})
      false
  """
  @spec expired?(t()) :: boolean()
  def expired?(%__MODULE__{expiry: nil}), do: false

  def expired?(%__MODULE__{expiry: expiry}) do
    case EDA.Timestamp.parse(expiry) do
      nil -> false
      dt -> DateTime.compare(dt, DateTime.utc_now()) == :lt
    end
  end

  @doc """
  Returns `true` if the poll results are finalized (votes precisely counted).

  ## Examples

      iex> EDA.Poll.finalized?(%EDA.Poll{results: {true, []}})
      true

      iex> EDA.Poll.finalized?(%EDA.Poll{results: {false, []}})
      false

      iex> EDA.Poll.finalized?(%EDA.Poll{results: nil})
      false
  """
  @spec finalized?(t()) :: boolean()
  def finalized?(%__MODULE__{results: {true, _}}), do: true
  def finalized?(%__MODULE__{}), do: false

  @doc """
  Returns the total number of votes across all answers.

  Returns 0 if there are no results.

  ## Examples

      iex> counts = [%EDA.Poll.AnswerCount{id: 1, count: 5, me_voted: false}, %EDA.Poll.AnswerCount{id: 2, count: 3, me_voted: true}]
      iex> EDA.Poll.total_votes(%EDA.Poll{results: {true, counts}})
      8

      iex> EDA.Poll.total_votes(%EDA.Poll{results: nil})
      0
  """
  @spec total_votes(t()) :: integer()
  def total_votes(%__MODULE__{results: nil}), do: 0

  def total_votes(%__MODULE__{results: {_finalized, counts}}) do
    Enum.reduce(counts, 0, fn %AnswerCount{count: c}, acc -> acc + c end)
  end

  @doc """
  Returns the answer with the most votes, or `nil` if there are no results.

  Matches answer counts back to answers by ID.

  ## Examples

      iex> answers = [%EDA.Poll.Answer{answer_id: 1, text: "A"}, %EDA.Poll.Answer{answer_id: 2, text: "B"}]
      iex> counts = [%EDA.Poll.AnswerCount{id: 1, count: 3, me_voted: false}, %EDA.Poll.AnswerCount{id: 2, count: 7, me_voted: false}]
      iex> EDA.Poll.winning_answer(%EDA.Poll{answers: answers, results: {true, counts}})
      %EDA.Poll.Answer{answer_id: 2, text: "B"}

      iex> EDA.Poll.winning_answer(%EDA.Poll{results: nil})
      nil
  """
  @spec winning_answer(t()) :: Answer.t() | nil
  def winning_answer(%__MODULE__{results: nil}), do: nil

  def winning_answer(%__MODULE__{results: {_finalized, []}}), do: nil

  def winning_answer(%__MODULE__{answers: answers, results: {_finalized, counts}}) do
    %AnswerCount{id: winner_id} = Enum.max_by(counts, & &1.count)
    Enum.find(answers, fn a -> a.answer_id == winner_id end)
  end

  # ── Private ──────────────────────────────────────────────────────────

  defp parse_answers(nil), do: []
  defp parse_answers(list) when is_list(list), do: Enum.map(list, &Answer.from_raw/1)

  defp parse_results(nil), do: nil

  defp parse_results(%{"is_finalized" => finalized, "answer_counts" => counts}) do
    {finalized, Enum.map(counts, &AnswerCount.from_raw/1)}
  end

  defp parse_results(%{"is_finalized" => finalized}) do
    {finalized, []}
  end

  defp resolve_answer_emoji(nil), do: nil
  defp resolve_answer_emoji(%EDA.Emoji{} = emoji), do: emoji
  defp resolve_answer_emoji(str) when is_binary(str), do: %EDA.Emoji{name: str}

  defp validate_length!(text, max, label) do
    len = String.length(text)

    if len > max do
      raise ArgumentError, "#{label} must be at most #{max} characters, got #{len}"
    end
  end

  defp validate_duration!(duration) do
    if duration < @min_duration or duration > @max_duration do
      raise ArgumentError,
            "duration must be between #{@min_duration} and #{@max_duration} hours, got #{duration}"
    end
  end
end

defimpl Jason.Encoder, for: EDA.Poll do
  def encode(poll, opts) do
    poll
    |> EDA.Poll.to_raw()
    |> Jason.Encode.map(opts)
  end
end
