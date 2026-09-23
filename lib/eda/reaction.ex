defmodule EDA.Reaction do
  @moduledoc "Represents a Discord message reaction."
  use EDA.Event.Access

  defstruct [:count, :me, :emoji, :count_details, :me_burst, :burst_colors]

  @type t :: %__MODULE__{
          count: integer() | nil,
          me: boolean() | nil,
          emoji: EDA.Emoji.t() | nil,
          count_details: %{burst: non_neg_integer(), normal: non_neg_integer()} | nil,
          me_burst: boolean() | nil,
          burst_colors: [String.t()] | nil
        }

  @spec from_raw(map()) :: t()
  def from_raw(%__MODULE__{} = parsed), do: parsed

  def from_raw(raw) when is_map(raw) do
    %__MODULE__{
      count: :maps.get("count", raw, nil),
      me: :maps.get("me", raw, nil),
      emoji: parse_emoji(:maps.get("emoji", raw, nil)),
      count_details: parse_count_details(:maps.get("count_details", raw, nil)),
      me_burst: :maps.get("me_burst", raw, nil),
      burst_colors: :maps.get("burst_colors", raw, nil)
    }
  end

  defp parse_emoji(nil), do: nil
  defp parse_emoji(raw) when is_map(raw), do: EDA.Emoji.from_raw(raw)

  # Discord's breakdown of the count: super reactions (burst) and normal ones.
  defp parse_count_details(%{"burst" => burst, "normal" => normal}),
    do: %{burst: burst, normal: normal}

  defp parse_count_details(_), do: nil

  @doc """
  The users who reacted to a message with an emoji, as `EDA.User` structs. Takes the options
  of `EDA.API.Reaction.list/4`: `:type` (`0` normal, `1` super reactions), `:after`, `:limit`.
  """
  @spec users(EDA.Message.t(), String.t() | EDA.Emoji.t(), keyword()) ::
          {:ok, [EDA.User.t()]} | {:error, term()}
  def users(%EDA.Message{channel_id: cid, id: mid}, emoji, opts \\ []) do
    case EDA.API.Reaction.list(cid, mid, emoji, opts) do
      {:ok, users} when is_list(users) -> {:ok, Enum.map(users, &EDA.User.from_raw/1)}
      {:error, _} = err -> err
    end
  end

  @doc "A lazy stream of every user who reacted with an emoji. Takes `:per_page` and `:after`."
  @spec stream_users(EDA.Message.t(), String.t() | EDA.Emoji.t(), keyword()) :: Enumerable.t()
  def stream_users(%EDA.Message{channel_id: cid, id: mid}, emoji, opts \\ []),
    do: cid |> EDA.API.Reaction.stream(mid, emoji, opts) |> Stream.map(&EDA.User.from_raw/1)
end
