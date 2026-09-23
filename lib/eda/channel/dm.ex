defmodule EDA.Channel.DM do
  @moduledoc """
  What only a direct message or group DM has, held in `EDA.Channel`'s `dm` field — `nil` on any
  other channel.

  - `recipients` — the other users, as `EDA.User` structs
  - `icon` — a group DM's icon hash
  - `application_id` and `managed` — set when an application created the group DM
  """

  use EDA.Event.Access

  defstruct [:recipients, :icon, :application_id, :managed]

  @type t :: %__MODULE__{
          recipients: [EDA.User.t()] | nil,
          icon: String.t() | nil,
          application_id: String.t() | nil,
          managed: boolean() | nil
        }

  @doc false
  def raw_keys, do: ~w(recipients icon application_id managed)

  @doc "Takes the direct message fields out of a raw channel object."
  @spec from_raw(map()) :: t()
  def from_raw(raw) when is_map(raw) do
    %__MODULE__{
      recipients: parse_users(raw["recipients"]),
      icon: raw["icon"],
      application_id: raw["application_id"],
      managed: raw["managed"]
    }
  end

  defp parse_users(nil), do: nil
  defp parse_users(list) when is_list(list), do: Enum.map(list, &EDA.User.from_raw/1)
end
