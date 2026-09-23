defmodule EDA.Role.Tags do
  @moduledoc """
  What a managed role belongs to: a bot (`bot_id`), an integration (`integration_id`), the
  guild's boosters (`premium_subscriber`), a role subscription (`subscription_listing_id`,
  `available_for_purchase`), or linked roles (`guild_connections`).

  Discord marks the last three by sending the key with a `null` value, and leaving it out
  otherwise; they are booleans here.
  """

  use EDA.Event.Access

  defstruct [
    :bot_id,
    :integration_id,
    :subscription_listing_id,
    premium_subscriber: false,
    available_for_purchase: false,
    guild_connections: false
  ]

  @type t :: %__MODULE__{
          bot_id: String.t() | nil,
          integration_id: String.t() | nil,
          subscription_listing_id: String.t() | nil,
          premium_subscriber: boolean(),
          available_for_purchase: boolean(),
          guild_connections: boolean()
        }

  @doc """
  A role's tags as Discord sends them.

      iex> EDA.Role.Tags.from_raw(%{"premium_subscriber" => nil})
      %EDA.Role.Tags{premium_subscriber: true}
      iex> EDA.Role.Tags.from_raw(%{"bot_id" => "1"})
      %EDA.Role.Tags{bot_id: "1", premium_subscriber: false}
  """
  @spec from_raw(map() | nil) :: t() | nil
  def from_raw(nil), do: nil

  def from_raw(raw) when is_map(raw) do
    %__MODULE__{
      bot_id: raw["bot_id"],
      integration_id: raw["integration_id"],
      subscription_listing_id: raw["subscription_listing_id"],
      premium_subscriber: Map.has_key?(raw, "premium_subscriber"),
      available_for_purchase: Map.has_key?(raw, "available_for_purchase"),
      guild_connections: Map.has_key?(raw, "guild_connections")
    }
  end
end
