defmodule EDA.Message.ChannelMention do
  @moduledoc """
  A channel a crossposted message mentions. Discord lists them only for a message followed in
  from an announcement channel, since the channels are in another guild; for any other
  message, the mentions are in its `content`, as `<#id>`.
  """

  use EDA.Event.Access

  defstruct [:id, :guild_id, :type, :name]

  @type t :: %__MODULE__{
          id: String.t() | nil,
          guild_id: String.t() | nil,
          type: EDA.Channel.channel_type() | nil,
          name: String.t() | nil
        }

  @doc false
  @spec from_raw(map()) :: t()
  def from_raw(%__MODULE__{} = parsed), do: parsed

  def from_raw(raw) when is_map(raw) do
    %__MODULE__{
      id: :maps.get("id", raw, nil),
      guild_id: :maps.get("guild_id", raw, nil),
      type: EDA.Channel.type_name(:maps.get("type", raw, nil)),
      name: :maps.get("name", raw, nil)
    }
  end
end
