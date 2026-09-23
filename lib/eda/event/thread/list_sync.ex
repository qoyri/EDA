defmodule EDA.Event.ThreadListSync do
  @moduledoc """
  Sent when the bot gains access to a channel, with the active threads in it: `threads` are
  `EDA.Channel` structs and `members` the bot's memberships, as `EDA.Channel.ThreadMember`.
  """
  use EDA.Event.Access
  defstruct [:guild_id, :channel_ids, :threads, :members]

  @type t :: %__MODULE__{
          guild_id: String.t() | nil,
          channel_ids: [String.t()] | nil,
          threads: [EDA.Channel.t()] | nil,
          members: [EDA.Channel.ThreadMember.t()] | nil
        }
  @doc "Converts a raw Discord payload into this event struct."
  @spec from_raw(map()) :: t()
  def from_raw(%__MODULE__{} = parsed), do: parsed

  def from_raw(raw) when is_map(raw) do
    %__MODULE__{
      guild_id: :maps.get("guild_id", raw, nil),
      channel_ids: :maps.get("channel_ids", raw, nil),
      threads: parse_list(:maps.get("threads", raw, nil), &EDA.Channel.from_raw/1),
      members: parse_list(:maps.get("members", raw, nil), &EDA.Channel.ThreadMember.from_raw/1)
    }
  end

  defp parse_list(nil, _parse), do: nil
  defp parse_list(list, parse) when is_list(list), do: Enum.map(list, parse)
end
