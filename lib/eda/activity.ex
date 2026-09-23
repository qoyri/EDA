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
  def from_raw(%__MODULE__{} = parsed), do: parsed

  def from_raw(raw) when is_map(raw) do
    %__MODULE__{
      name: :maps.get("name", raw, nil),
      type: EDA.Enum.name(@types, :maps.get("type", raw, nil)),
      url: :maps.get("url", raw, nil),
      created_at: EDA.Timestamp.from_unix_ms(:maps.get("created_at", raw, nil)),
      timestamps: EDA.Activity.Timestamps.from_raw(:maps.get("timestamps", raw, nil)),
      application_id: :maps.get("application_id", raw, nil),
      details: :maps.get("details", raw, nil),
      state: :maps.get("state", raw, nil),
      emoji: parse_emoji(:maps.get("emoji", raw, nil)),
      party: EDA.Activity.Party.from_raw(:maps.get("party", raw, nil)),
      assets: EDA.Activity.Assets.from_raw(:maps.get("assets", raw, nil)),
      secrets: EDA.Activity.Secrets.from_raw(:maps.get("secrets", raw, nil)),
      instance: :maps.get("instance", raw, nil),
      flags: :maps.get("flags", raw, nil),
      buttons: :maps.get("buttons", raw, nil),
      status_display_type:
        EDA.Enum.name(@status_display_types, :maps.get("status_display_type", raw, nil)),
      details_url: :maps.get("details_url", raw, nil),
      state_url: :maps.get("state_url", raw, nil)
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

  @doc """
  How long the activity has been going on, in seconds, from `timestamps.start`; `nil` when
  Discord sent no start.
  """
  @spec elapsed(t(), DateTime.t()) :: non_neg_integer() | nil
  def elapsed(activity, now \\ DateTime.utc_now())

  def elapsed(%__MODULE__{timestamps: %{start: %DateTime{} = start}}, now),
    do: max(DateTime.diff(now, start), 0)

  def elapsed(%__MODULE__{}, _now), do: nil

  @doc "How long until the activity ends, in seconds, from `timestamps.end`; `nil` without one."
  @spec remaining(t(), DateTime.t()) :: non_neg_integer() | nil
  def remaining(activity, now \\ DateTime.utc_now())

  def remaining(%__MODULE__{timestamps: %{end: %DateTime{} = finish}}, now),
    do: max(DateTime.diff(finish, now), 0)

  def remaining(%__MODULE__{}, _now), do: nil

  @doc """
  The URL of the activity's large image, or `nil`. Resolves the forms Discord uses: an
  application asset id, a proxied `mp:` image, and Spotify's `spotify:` covers.

      iex> EDA.Activity.large_image_url(%EDA.Activity{assets: %EDA.Activity.Assets{large_image: "spotify:ab67"}})
      "https://i.scdn.co/image/ab67"
      iex> EDA.Activity.large_image_url(%EDA.Activity{application_id: "9", assets: %EDA.Activity.Assets{large_image: "123"}})
      "https://cdn.discordapp.com/app-assets/9/123.png"
  """
  @spec large_image_url(t()) :: String.t() | nil
  def large_image_url(%__MODULE__{assets: %{large_image: image}} = activity),
    do: asset_url(image, activity.application_id)

  def large_image_url(%__MODULE__{}), do: nil

  @doc "The URL of the activity's small image, or `nil`. See `large_image_url/1`."
  @spec small_image_url(t()) :: String.t() | nil
  def small_image_url(%__MODULE__{assets: %{small_image: image}} = activity),
    do: asset_url(image, activity.application_id)

  def small_image_url(%__MODULE__{}), do: nil

  defp asset_url(nil, _app_id), do: nil
  defp asset_url("mp:" <> path, _app_id), do: "https://media.discordapp.net/" <> path
  defp asset_url("spotify:" <> id, _app_id), do: "https://i.scdn.co/image/" <> id

  defp asset_url(id, app_id) when is_binary(app_id),
    do: "#{EDA.CDN.base()}/app-assets/#{app_id}/#{id}.png"

  defp asset_url(_id, nil), do: nil
end
