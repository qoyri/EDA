defmodule EDA.API.Application do
  @moduledoc """
  REST API endpoints for the bot's own application.

  All functions return raw maps: `{:ok, map}` or `{:error, reason}`. `EDA.App` wraps them in
  a struct. (The struct is not called `EDA.Application`: that is EDA's OTP application.)
  """

  import Bitwise, only: [<<<: 2, |||: 2, &&&: 2, bnot: 1]
  import EDA.HTTP.Client

  @modify_keys ~w(custom_install_url description role_connections_verification_url
                  install_params integration_types_config flags icon cover_image
                  interactions_endpoint_url tags event_webhooks_url event_webhooks_status
                  event_webhooks_types)a

  # Only the "limited" intent flags can be set through the API; Discord refuses the rest.
  @settable_flags 1 <<< 13 ||| 1 <<< 15 ||| 1 <<< 19

  @integration_types %{guild_install: "0", user_install: "1"}
  @webhook_statuses %{disabled: 1, enabled: 2}

  @doc """
  Gets the application the bot belongs to.

  `GET /applications/@me`
  """
  @spec me() :: {:ok, map()} | {:error, term()}
  def me, do: EDA.HTTP.Client.get("/applications/@me")

  @doc """
  Edits the application the bot belongs to. Only the fields passed change.

  `PATCH /applications/@me`

  ## Options

    * `:description` — the app's description
    * `:icon`, `:cover_image` — image data: a path, raw PNG/JPEG/GIF bytes or a data URI, see
      `EDA.ImageData`; `nil` removes it
    * `:tags` — up to 5 tags of up to 20 characters each. Discord stores them in an order of
      its own, so compare them as sets; `[]` clears them
    * `:flags` — only the limited intents can be set here: `:gateway_presence_limited`,
      `:gateway_guild_members_limited`, `:gateway_message_content_limited`, as a list of those
      atoms or as an integer. Discord refuses any other flag
    * `:install_params` — the default in-app authorization link, as
      `%{scopes: [...], permissions: ...}`; `permissions` may be an integer, a string or a list
      of `EDA.Permission` atoms
    * `:integration_types_config` — the default scopes and permissions per installation context,
      keyed by `:guild_install` and `:user_install`, each with an `install_params` value:
      `%{guild_install: %{scopes: ["bot", "applications.commands"], permissions: [:send_messages]}}`
    * `:custom_install_url`, `:role_connections_verification_url`,
      `:interactions_endpoint_url` — URLs. Discord checks an interactions endpoint before
      accepting it
    * `:event_webhooks_url`, `:event_webhooks_types` — webhook events, and
      `:event_webhooks_status` as `:enabled` or `:disabled`

  ## Example

      EDA.API.Application.modify_me(description: "Moderation for busy servers", tags: ["moderation"])
  """
  @spec modify_me(keyword() | map()) :: {:ok, map()} | {:error, term()}
  def modify_me(opts) do
    body = Map.new(opts)
    check_options!(body, @modify_keys, "EDA.API.Application.modify_me/1")

    body =
      body
      |> update_present(:icon, &EDA.ImageData.coerce/1)
      |> update_present(:cover_image, &EDA.ImageData.coerce/1)
      |> update_present(:tags, &validate_tags!/1)
      |> update_present(:flags, &settable_flags!/1)
      |> update_present(:install_params, &install_params/1)
      |> update_present(:integration_types_config, &integration_types_config/1)
      |> update_present(:event_webhooks_status, &webhook_status!/1)

    patch("/applications/@me", body)
  end

  @doc """
  Gets an Activity instance of this application, if it exists.

  `GET /applications/{application_id}/activity-instances/{instance_id}`. Useful to check that a
  user joining an Activity session is really in it.
  """
  @spec activity_instance(String.t()) :: {:ok, map()} | {:error, term()}
  def activity_instance(instance_id) when is_binary(instance_id) do
    EDA.HTTP.Client.get("/applications/#{app_id()}/activity-instances/#{URI.encode(instance_id)}")
  end

  @doc false
  # The integer form of the three settable flags, for EDA.App and the tests.
  def settable_flags, do: @settable_flags

  defp update_present(body, key, fun) do
    case body do
      %{^key => value} -> Map.put(body, key, fun.(value))
      _ -> body
    end
  end

  defp validate_tags!(tags) when is_list(tags) do
    if length(tags) > 5 do
      raise ArgumentError, "an app has at most 5 tags, got #{length(tags)}"
    end

    for tag <- tags, String.length(tag) > 20 do
      raise ArgumentError, "an app tag is at most 20 characters, got #{inspect(tag)}"
    end

    tags
  end

  defp settable_flags!(flags) when is_list(flags) do
    flags |> Enum.map(&EDA.App.flag_value!/1) |> Enum.reduce(0, &|||/2) |> settable_flags!()
  end

  defp settable_flags!(flags) when is_integer(flags) do
    case flags &&& bnot(@settable_flags) do
      0 ->
        flags

      extra ->
        raise ArgumentError,
              "only the limited intent flags can be set through the API " <>
                "(:gateway_presence_limited, :gateway_guild_members_limited, " <>
                ":gateway_message_content_limited); also got #{inspect(EDA.App.flag_list(extra))}"
    end
  end

  defp install_params(%{} = params) do
    params
    |> Map.new(fn {k, v} -> {to_string(k), v} end)
    |> Map.update("permissions", nil, &permissions/1)
    |> Map.reject(fn {_k, v} -> is_nil(v) end)
  end

  defp permissions(bits) when is_integer(bits), do: Integer.to_string(bits)
  defp permissions(bits) when is_binary(bits), do: bits

  defp permissions(flags) when is_list(flags),
    do: flags |> EDA.Permission.to_bitset() |> permissions()

  defp integration_types_config(%{} = config) do
    Map.new(config, fn {type, value} ->
      key =
        Map.get(@integration_types, type) ||
          if(to_string(type) in ["0", "1"],
            do: to_string(type),
            else:
              raise(
                ArgumentError,
                "integration types are :guild_install and :user_install, got #{inspect(type)}"
              )
          )

      {key, integration_type_config(value)}
    end)
  end

  # Accepts the install params directly, or already nested under oauth2_install_params.
  defp integration_type_config(%{oauth2_install_params: params}),
    do: %{"oauth2_install_params" => install_params(params)}

  defp integration_type_config(%{"oauth2_install_params" => params}),
    do: %{"oauth2_install_params" => install_params(params)}

  defp integration_type_config(%{} = params),
    do: %{"oauth2_install_params" => install_params(params)}

  defp webhook_status!(status) when is_map_key(@webhook_statuses, status),
    do: Map.fetch!(@webhook_statuses, status)

  defp webhook_status!(status) when status in [1, 2], do: status

  defp webhook_status!(other) do
    raise ArgumentError,
          "event_webhooks_status is :enabled or :disabled, got #{inspect(other)}"
  end
end
