defmodule EDA.Event.AllShardsReady do
  @moduledoc """
  Fired once when all shards have finished loading their guilds.

  `guild_count` is the number of guilds loaded across every shard.
  """
  use EDA.Event.Access

  defstruct [:shard_count, :guild_count, :duration_ms]

  @type t :: %__MODULE__{
          shard_count: non_neg_integer() | nil,
          guild_count: non_neg_integer() | nil,
          duration_ms: non_neg_integer() | nil
        }

  @doc "Converts a raw payload into this event struct."
  @spec from_raw(map()) :: t()
  def from_raw(%__MODULE__{} = parsed), do: parsed

  def from_raw(raw) when is_map(raw) do
    %__MODULE__{
      shard_count: :maps.get("shard_count", raw, nil),
      guild_count: :maps.get("guild_count", raw, nil),
      duration_ms: :maps.get("duration_ms", raw, nil)
    }
  end
end
