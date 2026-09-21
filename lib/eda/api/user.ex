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

  @doc """
  Modifies the current bot user — its account-wide identity.

  `PATCH /users/@me`, taking `username`, `avatar` and `banner`. A per-guild profile is set
  with `EDA.API.Member.modify_me/2` instead, and overrides this one in that guild.

  `avatar` and `banner` are *image data*: a path or raw bytes is converted to a data URI
  for you, and `nil` clears the field. See `EDA.ImageData`.

      EDA.API.User.modify_me(%{username: "EDA", avatar: "priv/avatar.png"})

  Changing the username may randomise the discriminator, and Discord rate-limits it
  heavily — this is not a call to make on a schedule.
  """
  @spec modify_me(map() | keyword()) :: {:ok, map()} | {:error, term()}
  def modify_me(opts) when is_list(opts) do
    opts |> Map.new() |> modify_me()
  end

  def modify_me(payload) when is_map(payload) do
    check_options!(payload, [:username, :avatar, :banner], "EDA.API.User.modify_me/1")
    patch("/users/@me", Map.new(payload, &coerce_image_field/1))
  end

  defp coerce_image_field({key, value}) when key in [:avatar, :banner, "avatar", "banner"] do
    {key, EDA.ImageData.coerce(value)}
  end

  defp coerce_image_field(pair), do: pair

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
