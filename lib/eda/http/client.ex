defmodule EDA.HTTP.Client do
  @moduledoc false

  # Internal HTTP infrastructure for Discord REST API.
  # API endpoints live in EDA.API.* modules.

  require Logger

  @default_base_url "https://discord.com/api/v10"
  # Derived at compile time so it cannot drift from the released version again.
  @user_agent "DiscordBot (EDA, #{Mix.Project.config()[:version]})"

  # ── Public HTTP verbs (used by EDA.API.* modules) ──

  def get(path, opts \\ []), do: request(:get, path, nil, opts)
  def post(path, body, opts \\ []), do: request(:post, path, body, opts)
  def put(path, body, opts \\ []), do: request(:put, path, body, opts)
  def patch(path, body, opts \\ []), do: request(:patch, path, body, opts)
  def delete(path, opts \\ []), do: request(:delete, path, nil, opts)

  def request_multipart(method, path, json_payload, files, opts \\ []) do
    {reason, opts} = Keyword.pop(opts, :reason)
    url = base_url() <> path
    {body, content_type} = EDA.HTTP.Multipart.encode(json_payload, files)
    binary_body = IO.iodata_to_binary(body)
    bucket = EDA.HTTP.Bucket.key(method, path)

    headers =
      [
        {"Authorization", "Bot #{EDA.token()}"},
        {"Content-Type", content_type},
        {"User-Agent", @user_agent}
      ]
      |> maybe_add_reason(reason)

    EDA.HTTP.RateLimiter.queue(
      method,
      path,
      fn ->
        result =
          case method do
            :post -> HTTPoison.post(url, binary_body, headers)
            :patch -> HTTPoison.patch(url, binary_body, headers)
            :put -> HTTPoison.put(url, binary_body, headers)
          end

        handle_response(result, bucket)
      end,
      opts
    )
  end

  # Interaction responses bypass the rate limiter
  def interaction_request(path, body) do
    url = base_url() <> path

    case HTTPoison.post(url, Jason.encode!(body), json_headers()) do
      {:ok, %{status_code: code}} when code in 200..299 -> :ok
      {:ok, response} -> {:error, parse_error(response)}
      {:error, error} -> {:error, error}
    end
  end

  def interaction_request_multipart(path, body, files) do
    url = base_url() <> path
    {encoded, content_type} = EDA.HTTP.Multipart.encode(body, files)

    headers = [
      {"Content-Type", content_type},
      {"User-Agent", @user_agent}
    ]

    case HTTPoison.post(url, IO.iodata_to_binary(encoded), headers) do
      {:ok, %{status_code: code}} when code in 200..299 -> :ok
      {:ok, response} -> {:error, parse_error(response)}
      {:error, error} -> {:error, error}
    end
  end

  # ── Shared helpers ──

  @doc """
  Builds a query string, refusing any option outside `allowed`.

  Discord ignores a query parameter it does not recognise, so a misspelt filter does not
  fail — it silently widens or changes the result set. `limit` mistyped on a member listing
  returns one member instead of a thousand; `user_id` mistyped on an entitlement listing
  returns everybody's. Endpoints therefore declare the parameters Discord defines.
  """
  def with_query(path, opts, allowed) when is_list(allowed) do
    check_options(opts, allowed, path)
    with_query(path, opts)
  end

  @doc """
  Logs a warning for every key in `opts` that is not in `allowed`, naming `where`.

  Discord ignores a field or parameter it does not recognise, so an unknown key is never a
  harmless no-op: it is an option the caller believes they set. `limit` mistyped on a member
  listing returns one member instead of a thousand; `allowed_mention` instead of
  `allowed_mentions` lets a ping through.

  The request is **not** altered — an unknown key is still sent. If EDA's list is behind
  Discord's, the cost is a warning that should not have fired, never a working call that
  stops working. EDA 0.5 will raise instead of warning.

  Accepts a keyword list or a map, and always returns `:ok`.
  """
  def check_options(opts, allowed, where) when is_map(opts),
    do: check_options(Map.to_list(opts), allowed, where)

  def check_options(opts, allowed, where) when is_list(opts) and is_list(allowed) do
    case Keyword.keys(opts) -- allowed do
      [] ->
        :ok

      unknown ->
        Logger.warning(
          "[EDA] #{where}: unknown option#{if length(unknown) > 1, do: "s"} " <>
            "#{inspect(unknown)} — Discord ignores what it does not recognise, so this " <>
            "has no effect. Accepted: #{inspect(Enum.sort(allowed))}. " <>
            "The request was sent unchanged; EDA 0.5 will raise here instead."
        )
    end
  end

  def with_query(path, opts) do
    params =
      opts
      |> Enum.reject(fn {_, v} -> is_nil(v) end)
      |> URI.encode_query()

    if params == "", do: path, else: path <> "?" <> params
  end

  def build_message_payload(opts) do
    {files, opts} = extract_files(opts)
    payload = opts_to_payload(opts)

    if files == [] do
      payload
    else
      {payload, files}
    end
  end

  def embed_to_map(%EDA.Embed{} = embed), do: EDA.Embed.to_map(embed)
  def embed_to_map(map) when is_map(map), do: map

  def command_to_map(%EDA.Command{} = cmd), do: EDA.Command.to_map(cmd)
  def command_to_map(map) when is_map(map), do: map

  def resolve_emoji(%EDA.Emoji{} = emoji), do: EDA.Emoji.api_name(emoji)
  def resolve_emoji(emoji) when is_binary(emoji), do: emoji

  def app_id do
    case EDA.Cache.me() do
      %EDA.User{id: id} when not is_nil(id) -> id
      %{"id" => id} when not is_nil(id) -> id
      _ -> raise "application_id not available, bot not connected"
    end
  end

  def maybe_put(map, _key, nil), do: map
  def maybe_put(map, key, value), do: Map.put(map, key, value)

  def resolve_action_type(opts) do
    case Keyword.fetch(opts, :action_type) do
      {:ok, atom} when is_atom(atom) ->
        case EDA.AuditLog.action_type(atom) do
          nil -> opts
          int -> Keyword.put(opts, :action_type, int)
        end

      _ ->
        opts
    end
  end

  # ── Private HTTP internals ──

  defp request(method, path, body, opts) do
    {reason, opts} = Keyword.pop(opts, :reason)
    url = base_url() <> path
    bucket = EDA.HTTP.Bucket.key(method, path)

    EDA.HTTP.RateLimiter.queue(
      method,
      path,
      fn ->
        result =
          case method do
            :get -> HTTPoison.get(url, auth_headers(reason))
            :post -> HTTPoison.post(url, Jason.encode!(body), auth_json_headers(reason))
            :put -> HTTPoison.put(url, Jason.encode!(body), auth_json_headers(reason))
            :patch -> HTTPoison.patch(url, Jason.encode!(body), auth_json_headers(reason))
            :delete -> HTTPoison.delete(url, auth_headers(reason))
          end

        handle_response(result, bucket)
      end,
      opts
    )
  end

  defp handle_response({:ok, %{status_code: 204, headers: headers}}, bucket) do
    EDA.HTTP.RateLimiter.report_headers(bucket, headers)
    {:ok, nil}
  end

  defp handle_response({:ok, %{status_code: code, body: body, headers: headers}}, bucket)
       when code in 200..299 do
    EDA.HTTP.RateLimiter.report_headers(bucket, headers)

    case Jason.decode(body) do
      {:ok, data} -> {:ok, data}
      {:error, _} -> {:ok, body}
    end
  end

  defp handle_response({:ok, %{status_code: 429, body: body, headers: headers}}, _bucket) do
    retry_after = get_retry_after(headers, body)
    Logger.warning("Rate limited! Retry after #{retry_after}ms")
    {:error, {:rate_limited, retry_after}}
  end

  defp handle_response({:ok, response}, _bucket) do
    {:error, parse_error(response)}
  end

  defp handle_response({:error, error}, _bucket) do
    {:error, error}
  end

  defp parse_error(%{status_code: code, body: body}) do
    case Jason.decode(body) do
      {:ok, %{"message" => message, "code" => error_code} = parsed} ->
        error = %{status: code, message: message, code: error_code}

        case parsed do
          %{"errors" => errors} -> Map.put(error, :errors, errors)
          _ -> error
        end

      {:ok, data} ->
        %{status: code, data: data}

      {:error, _} ->
        %{status: code, body: body}
    end
  end

  defp get_retry_after(headers, body) do
    case List.keyfind(headers, "Retry-After", 0) || List.keyfind(headers, "retry-after", 0) do
      {_, value} ->
        String.to_integer(value) * 1000

      nil ->
        case Jason.decode(body) do
          {:ok, %{"retry_after" => seconds}} -> trunc(seconds * 1000)
          _ -> 5000
        end
    end
  end

  defp base_url do
    Application.get_env(:eda, :base_url, @default_base_url)
  end

  defp auth_headers(reason) do
    [{"Authorization", "Bot #{EDA.token()}"}, {"User-Agent", @user_agent}]
    |> maybe_add_reason(reason)
  end

  defp auth_json_headers(reason) do
    [
      {"Authorization", "Bot #{EDA.token()}"},
      {"Content-Type", "application/json"},
      {"User-Agent", @user_agent}
    ]
    |> maybe_add_reason(reason)
  end

  defp maybe_add_reason(headers, nil), do: headers

  defp maybe_add_reason(headers, reason),
    do: [{"X-Audit-Log-Reason", URI.encode(reason)} | headers]

  defp json_headers do
    [
      {"Content-Type", "application/json"},
      {"User-Agent", @user_agent}
    ]
  end

  # Keys this builder rewrites before they reach Discord. Every other key passes through
  # untouched — validating which keys an endpoint accepts is the caller's job, since
  # message create, edit and the webhook routes each accept a different set.
  @transformed_keys [:embed, :embeds, :poll, :v2]

  defp opts_to_payload(opts) do
    opts
    |> Keyword.drop(@transformed_keys)
    |> Map.new()
    |> put_embeds(opts)
    |> maybe_put_poll(opts[:poll])
    |> maybe_put_v2(opts[:v2])
  end

  defp put_embeds(payload, opts) do
    case {opts[:embed], opts[:embeds]} do
      {nil, nil} -> payload
      {embed, nil} -> Map.put(payload, :embeds, [embed_to_map(embed)])
      {nil, embeds} -> Map.put(payload, :embeds, Enum.map(embeds, &embed_to_map/1))
      {_, _} -> raise ArgumentError, "cannot specify both :embed and :embeds"
    end
  end

  defp maybe_put_poll(payload, nil), do: payload
  defp maybe_put_poll(payload, poll), do: Map.put(payload, :poll, poll_to_raw(poll))

  # IS_COMPONENTS_V2. Combined with any explicit `:flags` — `v2: true, flags: 4096` is a
  # silent components-v2 message, and overwriting would quietly drop the silence.
  @components_v2 32_768

  defp maybe_put_v2(payload, true),
    do: Map.update(payload, :flags, @components_v2, &Bitwise.bor(&1, @components_v2))

  defp maybe_put_v2(payload, _), do: payload

  defp poll_to_raw(%EDA.Poll{} = poll), do: EDA.Poll.to_raw(poll)
  defp poll_to_raw(map) when is_map(map), do: map

  defp extract_files(opts) do
    {file, opts} = Keyword.pop(opts, :file)
    {files, opts} = Keyword.pop(opts, :files, [])

    all_files =
      case {file, files} do
        {nil, files} -> files
        {file, []} -> [file]
        {_, _} -> raise ArgumentError, "cannot specify both :file and :files"
      end

    normalized = Enum.map(all_files, &normalize_file/1)
    {normalized, opts}
  end

  defp normalize_file(%EDA.File{} = file), do: file

  defp normalize_file({data, name}) when is_binary(data) and is_binary(name) do
    EDA.File.from_binary(data, name)
  end

  defp normalize_file({data, name, opts}) when is_binary(data) and is_binary(name) do
    EDA.File.from_binary(data, name, opts)
  end

  defp normalize_file(path) when is_binary(path) do
    EDA.File.from_path(path)
  end
end
