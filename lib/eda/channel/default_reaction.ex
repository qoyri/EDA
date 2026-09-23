defmodule EDA.Channel.DefaultReaction do
  @moduledoc """
  The emoji on each post's reaction button in a forum or media channel: a custom one by
  `emoji_id`, or a Unicode one in `emoji_name`.

  It encodes as Discord takes it, so it can be sent back when editing a channel.
  """

  use EDA.Event.Access

  defstruct [:emoji_id, :emoji_name]

  @type t :: %__MODULE__{emoji_id: String.t() | nil, emoji_name: String.t() | nil}

  @doc false
  @spec from_raw(map() | nil) :: t() | nil
  def from_raw(nil), do: nil

  def from_raw(raw) when is_map(raw),
    do: %__MODULE__{emoji_id: raw["emoji_id"], emoji_name: raw["emoji_name"]}
end

defimpl Jason.Encoder, for: EDA.Channel.DefaultReaction do
  def encode(reaction, opts), do: reaction |> Map.from_struct() |> Jason.Encode.map(opts)
end
