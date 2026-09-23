defmodule EDA.API.Invite do
  @moduledoc """
  REST API endpoints for Discord invites.

  All functions return `{:ok, result}` or `{:error, reason}`.

  ## Target users

  An invite can be restricted to a named list of people: only those users may accept it.
  EDA takes and returns plain lists of user ids everywhere, so `target_users/1` gives a list
  rather than the CSV Discord answers with, and `create/2` takes one.

  There are two ways to send that list, and `create/2` and `update_target_users/2` pick the
  right one. Up to 1000 ids go as a JSON array and are **in force when the call returns**.
  Beyond that, or when you hand over a CSV binary you already have, it is uploaded as
  `multipart/form-data` and applied **asynchronously**: poll `target_users_job_status/1` until
  it reports `:completed`.

  To change a list without rebuilding it, `add_target_user/2` and `remove_target_user/2` take
  one user, `add_target_users/2` and `remove_target_users/2` up to 1000 at a time. All four
  apply at once.
  """

  import EDA.HTTP.Client

  @create_keys ~w(max_age max_uses temporary unique target_type target_user_id
                  target_application_id role_ids target_users reason)a

  @get_keys ~w(with_counts guild_scheduled_event_id)a

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
    check_options!(opts, @get_keys, "EDA.API.Invite.get/2")
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

  Up to 1000 target users are sent as a JSON array and are in force when the call returns.
  A longer list, or a CSV binary, is uploaded instead and applied asynchronously — see
  `target_users_job_status/1`.
  """
  @spec create(String.t() | integer(), keyword() | map()) :: {:ok, map()} | {:error, term()}
  def create(channel_id, opts \\ []) do
    check_options!(opts, @create_keys, "EDA.API.Invite.create/2")
    {target_users, opts} = pop_target_users(opts)
    {reason, body} = pop_reason(opts)
    path = "/channels/#{channel_id}/invites"

    case target_users do
      nil -> post(path, body, reason)
      {:ids, ids} -> post(path, Map.put(body, :target_user_ids, ids), reason)
      {:csv, csv} -> request_form(:post, path, body, [target_users_field(csv)], reason)
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

  This is the CSV upload, which Discord applies asynchronously: a success here means the upload
  was accepted, not that the restriction is live. Poll `target_users_job_status/1`. To change a
  list in place instead, and at once, use `add_target_user/2`, `remove_target_user/2`,
  `add_target_users/2` or `remove_target_users/2`.

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
  Lets one more user accept an invite, leaving the rest of the list alone.

  `PUT /invites/{code}/target-users/{user_id}`. Applies at once, unlike a CSV upload. The
  caller must be the inviter or hold `MANAGE_GUILD`.

      EDA.API.Invite.add_target_user("abc123", "80351110224678912")
  """
  @spec add_target_user(String.t(), String.t() | integer()) :: :ok | {:error, term()}
  def add_target_user(invite_code, user_id) do
    no_content(EDA.HTTP.Client.put("/invites/#{invite_code}/target-users/#{user_id}", nil))
  end

  @doc """
  Stops one user from accepting an invite, leaving the rest of the list alone.

  `DELETE /invites/{code}/target-users/{user_id}`. Same permissions as `add_target_user/2`.
  """
  @spec remove_target_user(String.t(), String.t() | integer()) :: :ok | {:error, term()}
  def remove_target_user(invite_code, user_id) do
    no_content(EDA.HTTP.Client.delete("/invites/#{invite_code}/target-users/#{user_id}"))
  end

  @doc """
  Adds up to 1000 users to an invite's list at once, leaving the rest of it alone.

  `POST /invites/{code}/target-users/bulk-add`. Applies at once. Same permissions as
  `add_target_user/2`.

      EDA.API.Invite.add_target_users("abc123", ["80351110224678912", "82198898841029460"])
  """
  @spec add_target_users(String.t(), [String.t() | integer()]) :: :ok | {:error, term()}
  def add_target_users(invite_code, user_ids) when is_list(user_ids),
    do: bulk(invite_code, "bulk-add", user_ids)

  @doc """
  Removes up to 1000 users from an invite's list at once, leaving the rest of it alone.

  `POST /invites/{code}/target-users/bulk-delete`. Applies at once. Same permissions as
  `add_target_user/2`.
  """
  @spec remove_target_users(String.t(), [String.t() | integer()]) :: :ok | {:error, term()}
  def remove_target_users(invite_code, user_ids) when is_list(user_ids),
    do: bulk(invite_code, "bulk-delete", user_ids)

  @doc """
  Reports how far Discord has got applying an invite's target users.

  Only a CSV upload creates a job. A list sent as JSON — up to 1000 ids on `create/2`, or any
  of the in-place calls — applies at once and leaves nothing to poll, so this answers error
  `10124` (`EDA.Error.unknown_invite_target_users_job/0`).

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

  # Discord takes at most 1000 ids in one JSON array, on create and on the bulk routes.
  @max_ids 1000

  defp target_users_field(csv), do: {"target_users_file", "target_users.csv", csv}

  defp bulk(_invite_code, _action, []), do: :ok

  defp bulk(invite_code, action, user_ids) do
    if length(user_ids) > @max_ids do
      raise ArgumentError,
            "at most #{@max_ids} target users per call, got #{length(user_ids)}; " <>
              "send them in batches, or replace the list with update_target_users/2"
    end

    no_content(
      post("/invites/#{invite_code}/target-users/#{action}", %{
        user_ids: Enum.map(user_ids, &to_string/1)
      })
    )
  end

  defp no_content({:ok, _}), do: :ok
  defp no_content(error), do: error

  # A list short enough goes as JSON and applies at once; anything else is a CSV upload.
  defp classify_target_users(csv) when is_binary(csv), do: {:csv, csv}

  defp classify_target_users(ids) when is_list(ids) do
    if length(ids) > @max_ids,
      do: {:csv, to_csv(ids)},
      else: {:ids, Enum.map(ids, &to_string/1)}
  end

  defp pop_target_users(opts) when is_list(opts) do
    case Keyword.pop(opts, :target_users) do
      {nil, rest} -> {nil, rest}
      {value, rest} -> {classify_target_users(value), rest}
    end
  end

  defp pop_target_users(opts) when is_map(opts) do
    case Map.pop(opts, :target_users) do
      {nil, rest} -> {nil, rest}
      {value, rest} -> {classify_target_users(value), rest}
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
