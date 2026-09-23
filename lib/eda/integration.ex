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
          account: EDA.Integration.Account.t() | nil,
          synced_at: DateTime.t() | nil,
          subscriber_count: integer() | nil,
          revoked: boolean() | nil,
          application: EDA.App.t() | nil,
          scopes: [String.t()] | nil
        }

  @expire_behaviors %{0 => :remove_role, 1 => :kick}

  @doc "Converts a raw integration object into this struct."
  @spec from_raw(map()) :: t()
  def from_raw(%__MODULE__{} = parsed), do: parsed

  def from_raw(raw) when is_map(raw) do
    %__MODULE__{
      id: :maps.get("id", raw, nil),
      guild_id: :maps.get("guild_id", raw, nil),
      name: :maps.get("name", raw, nil),
      type: :maps.get("type", raw, nil),
      enabled: :maps.get("enabled", raw, nil),
      syncing: :maps.get("syncing", raw, nil),
      role_id: :maps.get("role_id", raw, nil),
      enable_emoticons: :maps.get("enable_emoticons", raw, nil),
      expire_behavior:
        Map.get(
          @expire_behaviors,
          :maps.get("expire_behavior", raw, nil),
          :maps.get("expire_behavior", raw, nil)
        ),
      expire_grace_period: :maps.get("expire_grace_period", raw, nil),
      user:
        if(is_map(:maps.get("user", raw, nil)),
          do: EDA.User.from_raw(:maps.get("user", raw, nil))
        ),
      account: EDA.Integration.Account.from_raw(:maps.get("account", raw, nil)),
      synced_at: EDA.Timestamp.parse(:maps.get("synced_at", raw, nil)),
      subscriber_count: :maps.get("subscriber_count", raw, nil),
      revoked: :maps.get("revoked", raw, nil),
      application:
        :maps.get("application", raw, nil) && EDA.App.from_raw(:maps.get("application", raw, nil)),
      scopes: :maps.get("scopes", raw, nil)
    }
  end

  @doc "Whether this integration is a bot or OAuth2 application rather than Twitch or YouTube."
  @spec application?(t()) :: boolean()
  def application?(%__MODULE__{type: type}), do: type == "discord"
end
