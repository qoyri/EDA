defmodule EDA.Activity do
  @moduledoc """
  What a user is doing, as their presence shows it: a game, a stream, a song, a custom status.

  Its parts are structs: `timestamps` (`EDA.Activity.Timestamps`, as `DateTime`s), `assets`,
  `party` and `secrets`. `buttons` are the labels of the activity's buttons; Discord does not
  send a bot their links.
  """
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
          timestamps: EDA.Activity.Timestamps.t() | nil,
          application_id: String.t() | nil,
          details: String.t() | nil,
          state: String.t() | nil,
          emoji: EDA.Emoji.t() | nil,
          party: EDA.Activity.Party.t() | nil,
          assets: EDA.Activity.Assets.t() | nil,
          secrets: EDA.Activity.Secrets.t() | nil,
          instance: boolean() | nil,
          flags: integer() | nil,
          buttons: [String.t()] | nil,
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
      timestamps: EDA.Activity.Timestamps.from_raw(raw["timestamps"]),
      application_id: raw["application_id"],
      details: raw["details"],
      state: raw["state"],
      emoji: parse_emoji(raw["emoji"]),
      party: EDA.Activity.Party.from_raw(raw["party"]),
      assets: EDA.Activity.Assets.from_raw(raw["assets"]),
      secrets: EDA.Activity.Secrets.from_raw(raw["secrets"]),
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

  @doc """
  What the activity supports — joining, spectating, syncing… — from `flags`, as
  `EDA.Activity.Flags` names them. Accepts a struct or a raw map, and gives `[]` when Discord
  sent none.

      iex> EDA.Activity.flags(%EDA.Activity{flags: 18})
      [:join, :sync]
  """
  @spec flags(t() | map()) :: [EDA.Activity.Flags.flag()]
  def flags(%__MODULE__{flags: flags}), do: EDA.Activity.Flags.to_list(flags)
  def flags(%{"flags" => flags}), do: EDA.Activity.Flags.to_list(flags)
  def flags(_), do: []

  @doc """
  Whether `flags` carries a flag.

      iex> EDA.Activity.flag?(%EDA.Activity{flags: 18}, :sync)
      true
  """
  @spec flag?(t() | map(), EDA.Activity.Flags.flag()) :: boolean()
  def flag?(%__MODULE__{flags: flags}, flag), do: EDA.Activity.Flags.has?(flags, flag)
  def flag?(%{"flags" => flags}, flag), do: EDA.Activity.Flags.has?(flags, flag)
  def flag?(_, _flag), do: false
end
