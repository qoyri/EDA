defmodule EDA.Event.PresenceUpdate do
  @moduledoc """
  Dispatched when a user's presence is updated. Needs the `:guild_presences` intent.

  A user's custom status (the activity of type 4) is **omitted** from `activities` when their
  profile is private: the *Friends Only* setting, *Friends & Small Servers Only* in a guild of
  more than 200 members, or the Private Profile that age assurance applies to a teen account
  (announced 2026-09-22, and not something an app opts into). Its absence therefore does not mean
  the user has no custom status, and expect to see it more often as those protections roll out.
  The other activity types are not affected, though Activity Sharing can hide them.

  `status` is `:online`, `:idle`, `:dnd` or `:offline` (an invisible user shows as offline).
  `client_status` maps each platform with a session to its status, as `EDA.Presence.platform/1`
  names them: `%{desktop: :idle, mobile: :online}`; `EDA.Presence.platforms/1` and
  `status_on/2` read it.
  """
  use EDA.Event.Access

  defstruct [:guild_id, :user, :status, :activities, :client_status]

  @type t :: %__MODULE__{
          guild_id: String.t() | nil,
          user: EDA.User.t() | nil,
          status: :online | :idle | :dnd | :offline | String.t() | nil,
          activities: [EDA.Activity.t()] | nil,
          client_status: %{EDA.Presence.platform() => EDA.Presence.session_status()} | nil
        }

  @doc "Converts a raw Discord payload into this event struct."
  @spec from_raw(map()) :: t()
  def from_raw(raw) when is_map(raw) do
    %__MODULE__{
      guild_id: raw["guild_id"],
      user: parse_user(raw["user"]),
      status: EDA.Presence.status_name(raw["status"]),
      activities: parse_activities(raw["activities"]),
      client_status: EDA.Presence.parse_client_status(raw["client_status"])
    }
  end

  defp parse_user(nil), do: nil
  defp parse_user(raw) when is_map(raw), do: EDA.User.from_raw(raw)

  defp parse_activities(nil), do: nil
  defp parse_activities(list) when is_list(list), do: Enum.map(list, &EDA.Activity.from_raw/1)
end
