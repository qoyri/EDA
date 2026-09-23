defmodule EDA.Guild.IncidentsData do
  @moduledoc """
  The guild's safety actions in force: until when invites and DMs are paused
  (`invites_disabled_until`, `dms_disabled_until`), and when Discord last detected DM spam or a
  raid. Each is a `DateTime`, `nil` when not set.

  `EDA.API.Guild.modify_incident_actions/2` sets the two pauses.
  """

  use EDA.Event.Access

  defstruct [
    :invites_disabled_until,
    :dms_disabled_until,
    :dm_spam_detected_at,
    :raid_detected_at
  ]

  @type t :: %__MODULE__{
          invites_disabled_until: DateTime.t() | nil,
          dms_disabled_until: DateTime.t() | nil,
          dm_spam_detected_at: DateTime.t() | nil,
          raid_detected_at: DateTime.t() | nil
        }

  @doc false
  @spec from_raw(map() | nil) :: t() | nil
  def from_raw(nil), do: nil

  def from_raw(%__MODULE__{} = parsed), do: parsed

  def from_raw(raw) when is_map(raw) do
    %__MODULE__{
      invites_disabled_until: EDA.Timestamp.parse(:maps.get("invites_disabled_until", raw, nil)),
      dms_disabled_until: EDA.Timestamp.parse(:maps.get("dms_disabled_until", raw, nil)),
      dm_spam_detected_at: EDA.Timestamp.parse(:maps.get("dm_spam_detected_at", raw, nil)),
      raid_detected_at: EDA.Timestamp.parse(:maps.get("raid_detected_at", raw, nil))
    }
  end
end
