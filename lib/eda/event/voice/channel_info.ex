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
  def from_raw(raw) when is_map(raw) do
    %__MODULE__{
      guild_id: raw["guild_id"],
      channels:
        Enum.map(raw["channels"] || [], fn c ->
          %{id: c["id"], status: c["status"], voice_start_time: unix_time(c["voice_start_time"])}
        end)
    }
  end

  @doc false
  # The voice session start, in Unix seconds. The reference types it as an integer, but the live
  # gateway sends it as a string ("1790002356"), so both are read.
  def unix_time(nil), do: nil
  def unix_time(seconds) when is_integer(seconds), do: DateTime.from_unix!(seconds)

  def unix_time(seconds) when is_binary(seconds) do
    case Integer.parse(seconds) do
      {n, ""} -> DateTime.from_unix!(n)
      _ -> nil
    end
  end

  def unix_time(_other), do: nil
end
