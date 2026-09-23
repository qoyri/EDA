defmodule EDA.Activity do
  @moduledoc "Represents a Discord presence activity."
  use EDA.Event.Access

  @status_display_types %{0 => :name, 1 => :state, 2 => :details}

  @types %{
    0 => :playing,
    1 => :streaming,
    2 => :listening,
    3 => :watching,
    4 => :custom,
    5 => :competing
  }

  defstruct [
    :name,
    :type,
    :url,
    :created_at,
    :timestamps,
    :application_id,
    :details,
    :state,
    :emoji,
    :party,
    :assets,
    :secrets,
    :instance,
    :flags,
    :buttons,
    :status_display_type,
    :details_url,
    :state_url
  ]

  @type t :: %__MODULE__{
          name: String.t() | nil,
          type:
            :playing
            | :streaming
            | :listening
            | :watching
            | :custom
            | :competing
            | integer()
            | nil,
          url: String.t() | nil,
          created_at: DateTime.t() | nil,
          timestamps: map() | nil,
          application_id: String.t() | nil,
          details: String.t() | nil,
          state: String.t() | nil,
          emoji: EDA.Emoji.t() | nil,
          party: map() | nil,
          assets: map() | nil,
          secrets: map() | nil,
          instance: boolean() | nil,
          flags: integer() | nil,
          buttons: [map()] | nil,
          status_display_type: :name | :state | :details | integer() | nil,
          details_url: String.t() | nil,
          state_url: String.t() | nil
        }

  @spec from_raw(map()) :: t()
  def from_raw(raw) when is_map(raw) do
    %__MODULE__{
      name: raw["name"],
      type: EDA.Enum.name(@types, raw["type"]),
      url: raw["url"],
      created_at: EDA.Timestamp.from_unix_ms(raw["created_at"]),
      timestamps: raw["timestamps"],
      application_id: raw["application_id"],
      details: raw["details"],
      state: raw["state"],
      emoji: parse_emoji(raw["emoji"]),
      party: raw["party"],
      assets: raw["assets"],
      secrets: raw["secrets"],
      instance: raw["instance"],
      flags: raw["flags"],
      buttons: raw["buttons"],
      status_display_type: EDA.Enum.name(@status_display_types, raw["status_display_type"]),
      details_url: raw["details_url"],
      state_url: raw["state_url"]
    }
  end

  defp parse_emoji(nil), do: nil
  defp parse_emoji(raw) when is_map(raw), do: EDA.Emoji.from_raw(raw)
end
