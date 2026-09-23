defmodule EDA.Ban do
  @moduledoc """
  A user banned from a guild, with the `reason` given, if any.

      {:ok, bans} = EDA.Ban.list(guild_id)
      EDA.Ban.create(guild_id, user_id, delete_message_seconds: 3600, reason: "spam")
  """

  use EDA.Event.Access

  defstruct [:guild_id, :user, :reason]

  @type t :: %__MODULE__{
          guild_id: String.t() | nil,
          user: EDA.User.t() | nil,
          reason: String.t() | nil
        }

  @doc false
  @spec from_raw(map()) :: t()
  def from_raw(raw) when is_map(raw) do
    %__MODULE__{
      guild_id: raw["guild_id"],
      user: raw["user"] && EDA.User.from_raw(raw["user"]),
      reason: raw["reason"]
    }
  end

  @doc "Lists one page of a guild's bans. Takes `:limit`, `:before` and `:after`."
  @spec list(String.t() | integer(), keyword()) :: {:ok, [t()]} | {:error, term()}
  def list(guild_id, opts \\ []) do
    case EDA.API.Ban.list(guild_id, opts) do
      {:ok, bans} when is_list(bans) -> {:ok, Enum.map(bans, &in_guild(&1, guild_id))}
      {:error, _} = err -> err
    end
  end

  @doc "A lazy stream of every ban in a guild. Takes the options of `EDA.API.Ban.stream/2`."
  @spec stream(String.t() | integer(), keyword()) :: Enumerable.t()
  def stream(guild_id, opts \\ []),
    do: guild_id |> EDA.API.Ban.stream(opts) |> Stream.map(&in_guild(&1, guild_id))

  @doc """
  Fetches the ban of one user, or `{:error, _}` when they are not banned.

  Named `fetch_ban/2` rather than `fetch/2` because `Access.fetch/2` owns that arity.
  """
  @spec fetch_ban(String.t() | integer(), EDA.User.t() | String.t() | integer()) ::
          {:ok, t()} | {:error, term()}
  def fetch_ban(guild_id, user) do
    case EDA.API.Ban.get(guild_id, user_id(user)) do
      {:ok, raw} when is_map(raw) -> {:ok, in_guild(raw, guild_id)}
      {:error, _} = err -> err
    end
  end

  @doc """
  Bans a user. Takes `:delete_message_seconds` (0–604800) and `:reason`.
  """
  @spec create(String.t() | integer(), EDA.User.t() | String.t() | integer(), keyword()) ::
          :ok | {:error, term()}
  def create(guild_id, user, opts \\ []), do: EDA.API.Ban.create(guild_id, user_id(user), opts)

  @doc "Lifts a ban. Takes the ban, the user or their id."
  @spec remove(String.t() | integer(), t() | EDA.User.t() | String.t() | integer()) ::
          :ok | {:error, term()}
  def remove(guild_id, %__MODULE__{user: user}), do: remove(guild_id, user)
  def remove(guild_id, user), do: EDA.API.Ban.remove(guild_id, user_id(user))

  @doc """
  Bans up to 200 users at once. Returns the ids Discord banned and those it did not.
  """
  @spec bulk(String.t() | integer(), [EDA.User.t() | String.t() | integer()], keyword()) ::
          {:ok, %{banned_users: [String.t()], failed_users: [String.t()]}} | {:error, term()}
  def bulk(guild_id, users, opts \\ []) do
    case EDA.API.Ban.bulk(guild_id, Enum.map(users, &user_id/1), opts) do
      {:ok, raw} when is_map(raw) ->
        {:ok, %{banned_users: raw["banned_users"] || [], failed_users: raw["failed_users"] || []}}

      {:error, _} = err ->
        err
    end
  end

  defp in_guild(raw, guild_id), do: %{from_raw(raw) | guild_id: to_string(guild_id)}

  defp user_id(%EDA.User{id: id}), do: id
  defp user_id(id), do: id
end
