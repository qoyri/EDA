defmodule EDA.Event.ChannelInfo do
  @moduledoc """
  A guild's ephemeral channel data — voice channel statuses and session start times — sent in
  answer to `EDA.Channel.request_info/2` (opcode 43). These fields are not part of the channel
  object, so this is the only way to read them.

  Each entry holds `:id`, and `:status` and `:voice_start_time` when they were requested.
  """
  use EDA.Event.Access

  defstruct [:guild_id, channels: []]

  @type channel :: %{
          id: String.t(),
          status: String.t() | nil,
          voice_start_time: DateTime.t() | nil
        }

  @type t :: %__MODULE__{guild_id: String.t() | nil, channels: [channel()]}

  @doc "Converts a raw Discord payload into this event struct."
  @spec from_raw(map()) :: t()
  def from_raw(%__MODULE__{} = parsed), do: parsed

  def from_raw(raw) when is_map(raw) do
    %__MODULE__{
      guild_id: :maps.get("guild_id", raw, nil),
      channels:
        Enum.map(:maps.get("channels", raw, nil) || [], fn c ->
          %{id: c["id"], status: c["status"], voice_start_time: unix_time(c["voice_start_time"])}
        end)
    }
  end

  @doc false
  # The voice session start, in Unix seconds. The reference types it as an integer, but the live
  # gateway sends it as a string ("1790002356"), so both are read.
  def unix_time(seconds), do: EDA.Timestamp.from_unix(seconds)
end
