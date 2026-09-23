defmodule EDA.Webhook do
  @moduledoc "Represents a Discord webhook."
  use EDA.Event.Access

  @types %{1 => :incoming, 2 => :channel_follower, 3 => :application}

  defstruct [
    :id,
    :type,
    :guild_id,
    :channel_id,
    :user,
    :name,
    :avatar,
    :token,
    :application_id,
    :source_guild,
    :source_channel,
    :url
  ]

  @type t :: %__MODULE__{
          id: String.t() | nil,
          type: :incoming | :channel_follower | :application | integer() | nil,
          guild_id: String.t() | nil,
          channel_id: String.t() | nil,
          user: EDA.User.t() | nil,
          name: String.t() | nil,
          avatar: String.t() | nil,
          token: String.t() | nil,
          application_id: String.t() | nil,
          source_guild: map() | nil,
          source_channel: map() | nil,
          url: String.t() | nil
        }

  @spec from_raw(map()) :: t()
  def from_raw(raw) when is_map(raw) do
    %__MODULE__{
      id: raw["id"],
      type: EDA.Enum.name(@types, raw["type"]),
      guild_id: raw["guild_id"],
      channel_id: raw["channel_id"],
      user: parse_user(raw["user"]),
      name: raw["name"],
      avatar: raw["avatar"],
      token: raw["token"],
      application_id: raw["application_id"],
      source_guild: raw["source_guild"],
      source_channel: raw["source_channel"],
      url: raw["url"]
    }
  end

  defp parse_user(nil), do: nil
  defp parse_user(raw) when is_map(raw), do: EDA.User.from_raw(raw)
end
