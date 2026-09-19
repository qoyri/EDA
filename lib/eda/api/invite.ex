defmodule EDA.API.Invite do
  @moduledoc """
  REST API endpoints for Discord invites.

  All functions return `{:ok, result}` or `{:error, reason}`.

  ## Target users

  An invite can be restricted to a named list of people: only those users may accept it.
  Discord carries that list as a **CSV file** rather than a JSON array, uploaded as
  `multipart/form-data` and processed asynchronously.

  EDA takes and returns plain lists of user ids and does the CSV on both sides, so
  `target_users: [...]` on `create/2` or `update_target_users/2` is all there is to it, and
  `target_users/1` gives a list back rather than a blob of text. The CSV itself is still
  reachable if you have one already — see `update_target_users/2`.

  Because the upload is asynchronous, the ids are **not** in force when the call returns.
  Poll `target_users_job_status/1` until it reports `:completed`.
  """

  import EDA.HTTP.Client

  @doc """
  Gets an invite by code.

  ## Options

    * `:with_counts` - include `approximate_member_count` and `approximate_presence_count`
    * `:guild_scheduled_event_id` - include that event as `guild_scheduled_event`

  ## Examples

      EDA.API.Invite.get("abc123", with_counts: true)
  """
  @spec get(String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def get(invite_code, opts \\ []) do
    EDA.HTTP.Client.get(with_query("/invites/#{invite_code}", opts))
  end

  @doc "Gets invites for a channel."
  @spec list_channel(String.t() | integer()) :: {:ok, [map()]} | {:error, term()}
  def list_channel(channel_id) do
    EDA.HTTP.Client.get("/channels/#{channel_id}/invites")
  end

  @doc """
  Creates an invite for a channel.

  Requires `CREATE_INSTANT_INVITE`.

  ## Options

    * `:max_age` - seconds until expiry, 0 for never. 0–604800, default 86400 (24h)
    * `:max_uses` - 0 for unlimited. 0–100, default 0
    * `:temporary` - grant temporary membership only
    * `:unique` - do not reuse a similar existing invite
    * `:target_type` - 1 for a stream, 2 for an embedded application
    * `:target_user_id` - required when `target_type` is 1
    * `:target_application_id` - required when `target_type` is 2
    * `:role_ids` - roles to give whoever accepts. Requires `MANAGE_ROLES`, and you cannot
      grant a role above your own
    * `:target_users` - user ids allowed to accept this invite, or a ready-made CSV binary
    * `:reason` - audit log reason

  ## Examples

      EDA.API.Invite.create(channel_id, max_age: 3600, max_uses: 1, unique: true)

      # an invite only these three can accept, which also grants them a role
      EDA.API.Invite.create(channel_id,
        target_users: ["80351110224678912", "82198898841029460"],
        role_ids: ["41771983423143936"]
      )

  Uploading `:target_users` makes this a `multipart/form-data` request and the list is
  applied asynchronously — see `target_users_job_status/1`.
  """
  @spec create(String.t() | integer(), keyword() | map()) :: {:ok, map()} | {:error, term()}
  def create(channel_id, opts \\ []) do
    {target_users, opts} = pop_target_users(opts)
    {reason, body} = pop_reason(opts)
    path = "/channels/#{channel_id}/invites"

    case target_users do
      nil -> post(path, body, reason)
      csv -> request_form(:post, path, body, [target_users_field(csv)], reason)
    end
  end

  @doc """
  Deletes an invite by code.

  Requires `MANAGE_CHANNELS` on the invite's channel, or `MANAGE_GUILD` for any invite in
  the guild.

  ## Options

    * `:reason` - audit log reason
  """
  @spec delete(String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def delete(invite_code, opts \\ []) do
    EDA.HTTP.Client.delete("/invites/#{invite_code}", opts)
  end

  @doc """
  Lists the user ids allowed to accept an invite.

  Returns `{:ok, ["8035...", ...]}`, or `{:ok, []}` when the invite has no target users.

  Discord answers with a CSV file; EDA parses it, so a caller never handles the text. The
  caller must be the inviter, or hold `MANAGE_GUILD` or `VIEW_AUDIT_LOG`.

  An invite that has never had a list answers with error `10129`
  (`EDA.Error.unknown_invite_target_users/0`), which is a legitimate state rather than a
  failure, so it is reported as an empty list.
  """
  @spec target_users(String.t()) :: {:ok, [String.t()]} | {:error, term()}
  def target_users(invite_code) do
    case EDA.HTTP.Client.get("/invites/#{invite_code}/target-users") do
      {:ok, csv} when is_binary(csv) -> {:ok, parse_csv(csv)}
      {:ok, nil} -> {:ok, []}
      {:error, %{code: 10_129}} -> {:ok, []}
      {:error, _} = err -> err
    end
  end

  @doc """
  Replaces the user ids allowed to accept an invite.

  Takes a list of ids, or a CSV binary if you already have one. The caller must be the
  inviter or hold `MANAGE_GUILD`.

  The list **replaces** whatever was there; passing `[]` clears it.

  Discord applies it asynchronously, so a success here means the upload was accepted, not
  that the restriction is live. Poll `target_users_job_status/1`.

  ## Examples

      EDA.API.Invite.update_target_users("abc123", ["80351110224678912"])

      # from a file you already have
      EDA.API.Invite.update_target_users("abc123", File.read!("guests.csv"))
  """
  @spec update_target_users(String.t(), [String.t() | integer()] | binary()) ::
          {:ok, map()} | {:error, term()}
  def update_target_users(invite_code, target_users) do
    request_form(
      :put,
      "/invites/#{invite_code}/target-users",
      %{},
      [target_users_field(to_csv(target_users))]
    )
  end

  @doc """
  Reports how far Discord has got applying an invite's target users.

  The raw `status` integer is replaced by an atom — `:unspecified`, `:processing`,
  `:completed` or `:failed` — under the `:status` key, with the rest of the payload left as
  Discord sent it.

      {:ok, %{status: :processing, "processed_users" => 120, "total_users" => 400}}

  The caller must be the inviter, or hold `MANAGE_GUILD` or `VIEW_AUDIT_LOG`.
  """
  @spec target_users_job_status(String.t()) :: {:ok, map()} | {:error, term()}
  def target_users_job_status(invite_code) do
    case EDA.HTTP.Client.get("/invites/#{invite_code}/target-users/job-status") do
      {:ok, raw} when is_map(raw) -> {:ok, Map.put(raw, :status, job_status(raw["status"]))}
      other -> other
    end
  end

  @doc """
  Names a target users job status integer.

  ## Examples

      iex> EDA.API.Invite.job_status(2)
      :completed

      iex> EDA.API.Invite.job_status(99)
      :unknown
  """
  @spec job_status(integer() | nil) ::
          :unspecified | :processing | :completed | :failed | :unknown
  def job_status(0), do: :unspecified
  def job_status(1), do: :processing
  def job_status(2), do: :completed
  def job_status(3), do: :failed
  def job_status(_other), do: :unknown

  # ── CSV ──

  @csv_header "user_id"

  @doc """
  Builds the CSV Discord expects from a list of user ids.

  A binary is assumed to be a CSV already and passed through, so callers can hand over a
  file they were given.

  ## Examples

      iex> EDA.API.Invite.to_csv(["123", 456])
      "user_id\\n123\\n456\\n"

      iex> EDA.API.Invite.to_csv([])
      "user_id\\n"
  """
  @spec to_csv([String.t() | integer()] | binary()) :: binary()
  def to_csv(csv) when is_binary(csv), do: csv

  def to_csv(ids) when is_list(ids) do
    Enum.reduce(ids, @csv_header <> "\n", &(&2 <> to_string(&1) <> "\n"))
  end

  @doc """
  Reads a target users CSV into a list of ids.

  Tolerates the `user_id` header Discord sends, blank lines, `\\r\\n`, and a stray trailing
  comma, because this parses a file rather than a field EDA controls.

  ## Examples

      iex> EDA.API.Invite.parse_csv("user_id\\n123\\n456\\n")
      ["123", "456"]

      iex> EDA.API.Invite.parse_csv("")
      []
  """
  @spec parse_csv(binary()) :: [String.t()]
  def parse_csv(csv) when is_binary(csv) do
    csv
    |> String.split(["\r\n", "\n"])
    |> Enum.map(&(&1 |> String.trim() |> String.trim_trailing(",")))
    |> Enum.reject(&(&1 == "" or &1 == @csv_header))
  end

  # ── Internals ──

  defp target_users_field(csv), do: {"target_users_file", "target_users.csv", csv}

  defp pop_target_users(opts) when is_list(opts) do
    case Keyword.pop(opts, :target_users) do
      {nil, rest} -> {nil, rest}
      {value, rest} -> {to_csv(value), rest}
    end
  end

  defp pop_target_users(opts) when is_map(opts) do
    case Map.pop(opts, :target_users) do
      {nil, rest} -> {nil, rest}
      {value, rest} -> {to_csv(value), rest}
    end
  end

  # `:reason` is a request option, not a body field, and `post/3` expects it as opts.
  defp pop_reason(opts) when is_list(opts) do
    {reason, rest} = Keyword.pop(opts, :reason)
    {reason_opts(reason), Map.new(rest)}
  end

  defp pop_reason(opts) when is_map(opts) do
    {reason, rest} = Map.pop(opts, :reason)
    {reason_opts(reason), rest}
  end

  defp reason_opts(nil), do: []
  defp reason_opts(reason), do: [reason: reason]
end
