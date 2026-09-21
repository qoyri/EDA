defmodule EDA.API.Invite do
  @moduledoc """
  REST API endpoints for Discord invites.

  All functions return `{:ok, result}` or `{:error, reason}`.
  """

  import EDA.HTTP.Client

  @doc "Gets invites for a channel."
  @spec list_channel(String.t() | integer()) :: {:ok, [map()]} | {:error, term()}
  def list_channel(channel_id) do
    EDA.HTTP.Client.get("/channels/#{channel_id}/invites")
  end

  @doc "Creates an invite for a channel."
  @spec create(String.t() | integer(), keyword() | map()) :: {:ok, map()} | {:error, term()}
  def create(channel_id, opts \\ []) do
    body = if is_list(opts), do: Map.new(opts), else: opts

    # `max_ages: 3600` would give the default 24-hour invite while looking like one hour.
    check_options(
      body,
      ~w(max_age max_uses temporary unique target_type target_user_id target_application_id role_ids)a,
      "EDA.API.Invite.create/2"
    )

    post("/channels/#{channel_id}/invites", body)
  end

  @doc "Deletes an invite by code."
  @spec delete(String.t()) :: {:ok, map()} | {:error, term()}
  def delete(invite_code) do
    EDA.HTTP.Client.delete("/invites/#{invite_code}")
  end
end
