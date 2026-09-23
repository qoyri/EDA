defmodule EDA.Event.Ready do
  @moduledoc """
  Dispatched when the client has completed the initial handshake.

  `guilds` are the guilds the bot is in, as `EDA.Guild` structs with only `id` and
  `unavailable: true`: each arrives in full in a `GUILD_CREATE` (or `GUILD_AVAILABLE`) after.
  `application` is an `EDA.App` with its `id` and `flags`.
  """
  use EDA.Event.Access
  defstruct [:v, :user, :guilds, :session_id, :resume_gateway_url, :shard, :application]

  @type t :: %__MODULE__{
          v: integer() | nil,
          user: EDA.User.t() | nil,
          guilds: [EDA.Guild.t()] | nil,
          session_id: String.t() | nil,
          resume_gateway_url: String.t() | nil,
          shard: [integer()] | nil,
          application: EDA.App.t() | nil
        }

  @doc "Converts a raw Discord payload into this event struct."
  @spec from_raw(map()) :: t()
  def from_raw(%__MODULE__{} = parsed), do: parsed

  def from_raw(raw) when is_map(raw) do
    %__MODULE__{
      v: :maps.get("v", raw, nil),
      user: parse_user(:maps.get("user", raw, nil)),
      guilds:
        :maps.get("guilds", raw, nil) &&
          Enum.map(:maps.get("guilds", raw, nil), &EDA.Guild.from_raw/1),
      session_id: :maps.get("session_id", raw, nil),
      resume_gateway_url: :maps.get("resume_gateway_url", raw, nil),
      shard: :maps.get("shard", raw, nil),
      application:
        :maps.get("application", raw, nil) && EDA.App.from_raw(:maps.get("application", raw, nil))
    }
  end

  defp parse_user(nil), do: nil
  defp parse_user(raw) when is_map(raw), do: EDA.User.from_raw(raw)
end
