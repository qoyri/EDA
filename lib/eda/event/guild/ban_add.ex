defmodule EDA.Event.GuildBanAdd do
  @moduledoc "Dispatched when a user is banned from a guild."
  use EDA.Event.Access
  defstruct [:guild_id, :user]
  @type t :: %__MODULE__{guild_id: String.t() | nil, user: EDA.User.t() | nil}
  @doc "Converts a raw Discord payload into this event struct."
  @spec from_raw(map()) :: t()
  def from_raw(%__MODULE__{} = parsed), do: parsed

  def from_raw(raw) when is_map(raw) do
    %__MODULE__{
      guild_id: :maps.get("guild_id", raw, nil),
      user: parse_user(:maps.get("user", raw, nil))
    }
  end

  defp parse_user(nil), do: nil
  defp parse_user(raw) when is_map(raw), do: EDA.User.from_raw(raw)
end
