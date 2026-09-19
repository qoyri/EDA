defmodule EDA.Event.RateLimited do
  @moduledoc """
  Dispatched when the app hits a gateway rate limit for an opcode.

  Discord currently only documents `meta` for opcode 8 (Request Guild
  Members), whose metadata carries the `guild_id` and the request `nonce`.
  Both are flattened here for convenience; `meta` keeps the raw map.
  """
  use EDA.Event.Access
  defstruct [:opcode, :retry_after, :guild_id, :nonce, :meta]

  @type t :: %__MODULE__{
          opcode: integer() | nil,
          retry_after: float() | nil,
          guild_id: String.t() | nil,
          nonce: String.t() | nil,
          meta: map() | nil
        }

  @doc "Converts a raw Discord payload into this event struct."
  @spec from_raw(map()) :: t()
  def from_raw(raw) when is_map(raw) do
    meta = raw["meta"] || %{}

    %__MODULE__{
      opcode: raw["opcode"],
      retry_after: raw["retry_after"],
      guild_id: meta["guild_id"],
      nonce: meta["nonce"],
      meta: raw["meta"]
    }
  end
end
