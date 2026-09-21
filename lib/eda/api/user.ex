defmodule EDA.API.User do
  @moduledoc """
  REST API endpoints for Discord users.

  All functions return `{:ok, result}` or `{:error, reason}`.
  """

  import EDA.HTTP.Client

  @doc "Gets the current bot user."
  @spec me() :: {:ok, map()} | {:error, term()}
  def me do
    EDA.HTTP.Client.get("/users/@me")
  end

  @doc "Modifies the current bot user."
  @spec modify_me(map() | keyword()) :: {:ok, map()} | {:error, term()}
  def modify_me(opts) do
    body = Map.new(opts)
    check_options!(body, [:username, :avatar, :banner], "EDA.API.User.modify_me/1")
    patch("/users/@me", body)
  end

  @doc "Gets a user by ID."
  @spec get(String.t() | integer()) :: {:ok, map()} | {:error, term()}
  def get(user_id) do
    EDA.HTTP.Client.get("/users/#{user_id}")
  end

  @doc "Creates a DM channel with a user."
  @spec create_dm(String.t() | integer()) :: {:ok, map()} | {:error, term()}
  def create_dm(user_id) do
    post("/users/@me/channels", %{recipient_id: user_id})
  end
end
