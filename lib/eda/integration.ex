defmodule EDA.Integration do
  @moduledoc """
  A guild integration: a Twitch or YouTube connection, a guild subscription, or a bot or OAuth2
  application added to the guild (`type: "discord"`).

  Arrives with the `INTEGRATION_CREATE` and `INTEGRATION_UPDATE` events, which also carry the
  `guild_id`. Fields marked Twitch/YouTube-only in Discord's reference are `nil` for a `discord`
  integration.
  """

  use EDA.Event.Access

  defstruct [
    :id,
    :guild_id,
    :name,
    :type,
    :enabled,
    :syncing,
    :role_id,
    :enable_emoticons,
    :expire_behavior,
    :expire_grace_period,
    :user,
    :account,
    :synced_at,
    :subscriber_count,
    :revoked,
    :application,
    :scopes
  ]

  @type t :: %__MODULE__{
          id: String.t() | nil,
          guild_id: String.t() | nil,
          name: String.t() | nil,
          type: String.t() | nil,
          enabled: boolean() | nil,
          syncing: boolean() | nil,
          role_id: String.t() | nil,
          enable_emoticons: boolean() | nil,
          expire_behavior: :remove_role | :kick | integer() | nil,
          expire_grace_period: integer() | nil,
          user: EDA.User.t() | nil,
          account: map() | nil,
          synced_at: DateTime.t() | nil,
          subscriber_count: integer() | nil,
          revoked: boolean() | nil,
          application: map() | nil,
          scopes: [String.t()] | nil
        }

  @expire_behaviors %{0 => :remove_role, 1 => :kick}

  @doc "Converts a raw integration object into this struct."
  @spec from_raw(map()) :: t()
  def from_raw(raw) when is_map(raw) do
    %__MODULE__{
      id: raw["id"],
      guild_id: raw["guild_id"],
      name: raw["name"],
      type: raw["type"],
      enabled: raw["enabled"],
      syncing: raw["syncing"],
      role_id: raw["role_id"],
      enable_emoticons: raw["enable_emoticons"],
      expire_behavior: Map.get(@expire_behaviors, raw["expire_behavior"], raw["expire_behavior"]),
      expire_grace_period: raw["expire_grace_period"],
      user: if(is_map(raw["user"]), do: EDA.User.from_raw(raw["user"])),
      account: raw["account"],
      synced_at: EDA.Timestamp.parse(raw["synced_at"]),
      subscriber_count: raw["subscriber_count"],
      revoked: raw["revoked"],
      application: raw["application"],
      scopes: raw["scopes"]
    }
  end

  @doc "Whether this integration is a bot or OAuth2 application rather than Twitch or YouTube."
  @spec application?(t()) :: boolean()
  def application?(%__MODULE__{type: type}), do: type == "discord"
end
