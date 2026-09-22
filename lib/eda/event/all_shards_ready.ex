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
  def from_raw(raw) when is_map(raw) do
    %__MODULE__{
      shard_count: raw["shard_count"],
      guild_count: raw["guild_count"],
      duration_ms: raw["duration_ms"]
    }
  end
end
