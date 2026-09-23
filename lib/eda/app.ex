defmodule EDA.App do
  @moduledoc """
  The Discord application a bot belongs to — its public profile, install settings and flags.

      {:ok, app} = EDA.App.me()
      app.name
      EDA.App.flags(app)            #=> [:gateway_message_content_limited, :application_command_badge]
      EDA.App.integration_types(app) #=> [:guild_install, :user_install]

  Named `EDA.App` because `EDA.Application` is EDA's own OTP application.

  The struct keeps the fields a bot has use for. Discord's response carries more — `rpc_origins`
  for desktop RPC apps, and a number of undocumented ones — which `EDA.API.Application.me/0`
  returns as they are.

  ## Flags

  Discord serialises `flags` as a number that will never grow past 31 bits; any flag above bit
  30 appears only in `flags_new`, a **string**. `from_raw/1` reads `flags_new` when it is there,
  so `:flags` holds the complete set as an integer, and code that only ever read `flags` does not
  silently miss the newer bits. `flags/1` names them.

  ## Editing

  `modify/1` edits the application; see `EDA.API.Application.modify_me/1` for the fields. Only
  the limited intent flags can be changed through the API.
  """

  use EDA.Event.Access

  import Bitwise

  defstruct [
    :id,
    :name,
    :icon,
    :description,
    :bot_public,
    :bot_require_code_grant,
    :bot,
    :terms_of_service_url,
    :privacy_policy_url,
    :owner,
    :verify_key,
    :team,
    :guild_id,
    :guild,
    :primary_sku_id,
    :slug,
    :cover_image,
    :flags,
    :approximate_guild_count,
    :approximate_user_install_count,
    :approximate_user_authorization_count,
    :redirect_uris,
    :interactions_endpoint_url,
    :role_connections_verification_url,
    :event_webhooks_url,
    :event_webhooks_status,
    :event_webhooks_types,
    :tags,
    :install_params,
    :integration_types_config,
    :custom_install_url
  ]

  @type install_params :: %{scopes: [String.t()], permissions: non_neg_integer()}

  @type t :: %__MODULE__{
          id: String.t() | nil,
          name: String.t() | nil,
          icon: String.t() | nil,
          description: String.t() | nil,
          bot_public: boolean() | nil,
          bot_require_code_grant: boolean() | nil,
          bot: EDA.User.t() | nil,
          terms_of_service_url: String.t() | nil,
          privacy_policy_url: String.t() | nil,
          owner: EDA.User.t() | nil,
          verify_key: String.t() | nil,
          team: EDA.Team.t() | nil,
          guild_id: String.t() | nil,
          guild: EDA.Guild.t() | nil,
          primary_sku_id: String.t() | nil,
          slug: String.t() | nil,
          cover_image: String.t() | nil,
          flags: non_neg_integer() | nil,
          approximate_guild_count: non_neg_integer() | nil,
          approximate_user_install_count: non_neg_integer() | nil,
          approximate_user_authorization_count: non_neg_integer() | nil,
          redirect_uris: [String.t()] | nil,
          interactions_endpoint_url: String.t() | nil,
          role_connections_verification_url: String.t() | nil,
          event_webhooks_url: String.t() | nil,
          event_webhooks_status: :disabled | :enabled | :disabled_by_discord | integer() | nil,
          event_webhooks_types: [String.t()] | nil,
          tags: [String.t()] | nil,
          install_params: install_params() | nil,
          integration_types_config: %{atom() => install_params() | nil} | nil,
          custom_install_url: String.t() | nil
        }

  @flags %{
    application_auto_moderation_rule_create_badge: 1 <<< 6,
    gateway_presence: 1 <<< 12,
    gateway_presence_limited: 1 <<< 13,
    gateway_guild_members: 1 <<< 14,
    gateway_guild_members_limited: 1 <<< 15,
    verification_pending_guild_limit: 1 <<< 16,
    embedded: 1 <<< 17,
    gateway_message_content: 1 <<< 18,
    gateway_message_content_limited: 1 <<< 19,
    application_command_badge: 1 <<< 23
  }

  @type flag ::
          :application_auto_moderation_rule_create_badge
          | :gateway_presence
          | :gateway_presence_limited
          | :gateway_guild_members
          | :gateway_guild_members_limited
          | :verification_pending_guild_limit
          | :embedded
          | :gateway_message_content
          | :gateway_message_content_limited
          | :application_command_badge

  @integration_types %{"0" => :guild_install, "1" => :user_install}
  @webhook_statuses %{1 => :disabled, 2 => :enabled, 3 => :disabled_by_discord}

  @cdn "https://cdn.discordapp.com"

  @doc """
  Converts a raw application object into this struct.

      iex> app = EDA.App.from_raw(%{"id" => "1", "name" => "Bot", "flags" => 8192, "flags_new" => "8192"})
      iex> {app.name, app.flags}
      {"Bot", 8192}
  """
  @spec from_raw(map()) :: t()
  def from_raw(%__MODULE__{} = parsed), do: parsed

  def from_raw(raw) when is_map(raw) do
    %__MODULE__{
      id: :maps.get("id", raw, nil),
      name: :maps.get("name", raw, nil),
      icon: :maps.get("icon", raw, nil),
      description: :maps.get("description", raw, nil),
      bot_public: :maps.get("bot_public", raw, nil),
      bot_require_code_grant: :maps.get("bot_require_code_grant", raw, nil),
      bot: user(:maps.get("bot", raw, nil)),
      terms_of_service_url: :maps.get("terms_of_service_url", raw, nil),
      privacy_policy_url: :maps.get("privacy_policy_url", raw, nil),
      owner: user(:maps.get("owner", raw, nil)),
      verify_key: :maps.get("verify_key", raw, nil),
      team: EDA.Team.from_raw(:maps.get("team", raw, nil)),
      guild_id: :maps.get("guild_id", raw, nil),
      guild: :maps.get("guild", raw, nil) && EDA.Guild.from_raw(:maps.get("guild", raw, nil)),
      primary_sku_id: :maps.get("primary_sku_id", raw, nil),
      slug: :maps.get("slug", raw, nil),
      cover_image: :maps.get("cover_image", raw, nil),
      flags: parse_flags(:maps.get("flags_new", raw, nil), :maps.get("flags", raw, nil)),
      approximate_guild_count: :maps.get("approximate_guild_count", raw, nil),
      approximate_user_install_count: :maps.get("approximate_user_install_count", raw, nil),
      approximate_user_authorization_count:
        :maps.get("approximate_user_authorization_count", raw, nil),
      redirect_uris: :maps.get("redirect_uris", raw, nil),
      interactions_endpoint_url: :maps.get("interactions_endpoint_url", raw, nil),
      role_connections_verification_url: :maps.get("role_connections_verification_url", raw, nil),
      event_webhooks_url: :maps.get("event_webhooks_url", raw, nil),
      event_webhooks_status:
        Map.get(
          @webhook_statuses,
          :maps.get("event_webhooks_status", raw, nil),
          :maps.get("event_webhooks_status", raw, nil)
        ),
      event_webhooks_types: :maps.get("event_webhooks_types", raw, nil),
      tags: :maps.get("tags", raw, nil),
      install_params: parse_install_params(:maps.get("install_params", raw, nil)),
      integration_types_config:
        parse_integration_types(:maps.get("integration_types_config", raw, nil)),
      custom_install_url: :maps.get("custom_install_url", raw, nil)
    }
  end

  # ── Flags ──────────────────────────────────────────────────────────

  @doc """
  The flags set on the app, as atoms. Bits Discord has not documented are left out.

      iex> EDA.App.flags(%EDA.App{flags: 524_288 + 8_388_608})
      [:gateway_message_content_limited, :application_command_badge]
  """
  @spec flags(t()) :: [flag()]
  def flags(%__MODULE__{flags: flags}), do: flag_list(flags || 0)

  @doc "Whether the app has `flag` set."
  @spec has_flag?(t(), flag()) :: boolean()
  def has_flag?(%__MODULE__{flags: flags}, flag), do: ((flags || 0) &&& flag_value!(flag)) != 0

  @doc false
  @spec flag_list(non_neg_integer()) :: [flag()]
  def flag_list(bits) when is_integer(bits) do
    @flags
    |> Enum.filter(fn {_name, bit} -> (bits &&& bit) != 0 end)
    |> Enum.sort_by(fn {_name, bit} -> bit end)
    |> Enum.map(fn {name, _bit} -> name end)
  end

  @doc false
  @spec flag_value!(flag()) :: pos_integer()
  def flag_value!(flag) do
    Map.get(@flags, flag) ||
      raise ArgumentError,
            "unknown app flag #{inspect(flag)}; known: #{inspect(Map.keys(@flags) |> Enum.sort())}"
  end

  # ── Install contexts ───────────────────────────────────────────────

  @doc """
  Where the app can be installed: `:guild_install`, `:user_install`, or both.

      iex> EDA.App.integration_types(%EDA.App{integration_types_config: %{guild_install: nil}})
      [:guild_install]
  """
  @spec integration_types(t()) :: [:guild_install | :user_install]
  def integration_types(%__MODULE__{integration_types_config: nil}), do: []

  def integration_types(%__MODULE__{integration_types_config: config}),
    do: config |> Map.keys() |> Enum.sort()

  # ── URLs ───────────────────────────────────────────────────────────

  @doc "The app's icon URL, or `nil` when it has none."
  @spec icon_url(t(), keyword()) :: String.t() | nil
  def icon_url(app, opts \\ [])
  def icon_url(%__MODULE__{icon: nil}, _opts), do: nil

  def icon_url(%__MODULE__{id: id, icon: hash}, opts),
    do: cdn("app-icons/#{id}/#{hash}", opts)

  @doc "The app's rich presence cover image URL, or `nil`."
  @spec cover_image_url(t(), keyword()) :: String.t() | nil
  def cover_image_url(app, opts \\ [])
  def cover_image_url(%__MODULE__{cover_image: nil}, _opts), do: nil

  def cover_image_url(%__MODULE__{id: id, cover_image: hash}, opts),
    do: cdn("app-icons/#{id}/#{hash}", opts)

  # ── Entity Manager ─────────────────────────────────────────────────

  @doc "Fetches the application the bot belongs to."
  @spec me() :: {:ok, t()} | {:error, term()}
  def me, do: wrap(EDA.API.Application.me())

  @doc """
  Edits the application the bot belongs to and returns it updated. See
  `EDA.API.Application.modify_me/1` for the fields.

      EDA.App.modify(description: "Moderation for busy servers", tags: ["moderation"])
  """
  @spec modify(keyword() | map()) :: {:ok, t()} | {:error, term()}
  def modify(opts), do: wrap(EDA.API.Application.modify_me(opts))

  defp wrap({:ok, raw}), do: {:ok, from_raw(raw)}
  defp wrap(error), do: error

  defp cdn(path, opts) do
    format = Keyword.get(opts, :format, "png")
    url = "#{@cdn}/#{path}.#{format}"

    case Keyword.get(opts, :size) do
      nil -> url
      size -> "#{url}?size=#{size}"
    end
  end

  # flags_new carries every bit and wins; flags stops at 31 bits.
  defp parse_flags(flags_new, _flags) when is_binary(flags_new) do
    case Integer.parse(flags_new) do
      {bits, ""} -> bits
      _ -> nil
    end
  end

  defp parse_flags(_flags_new, flags) when is_integer(flags), do: flags
  defp parse_flags(_flags_new, _flags), do: nil

  defp parse_install_params(%{} = params) do
    %{
      scopes: params["scopes"] || [],
      permissions: parse_permissions(params["permissions"])
    }
  end

  defp parse_install_params(_), do: nil

  defp parse_permissions(bits) when is_binary(bits) do
    case Integer.parse(bits) do
      {n, ""} -> n
      _ -> 0
    end
  end

  defp parse_permissions(bits) when is_integer(bits), do: bits
  defp parse_permissions(_), do: 0

  defp parse_integration_types(%{} = config) do
    Map.new(config, fn {type, value} ->
      key = Map.get(@integration_types, to_string(type), type)
      {key, parse_install_params((value || %{})["oauth2_install_params"])}
    end)
  end

  defp parse_integration_types(_), do: nil

  defp user(%{} = raw), do: EDA.User.from_raw(raw)
  defp user(_), do: nil
end
