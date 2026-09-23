defmodule EDA.Command.Permissions do
  @moduledoc """
  Who may use one of the app's commands in a guild — or every command, when `id` is the
  application id.

  Arrives with `APPLICATION_COMMAND_PERMISSIONS_UPDATE`. Each entry allows or denies a role, a
  user or a channel. Two ids are constants rather than real ids: the guild id stands for
  `@everyone`, and the guild id minus one for every channel — `everyone?/2` and
  `all_channels?/2` recognise them.
  """

  use EDA.Event.Access

  defstruct [:id, :application_id, :guild_id, permissions: []]

  @type entry :: %{
          id: String.t(),
          type: :role | :user | :channel | integer(),
          permission: boolean()
        }

  @type t :: %__MODULE__{
          id: String.t() | nil,
          application_id: String.t() | nil,
          guild_id: String.t() | nil,
          permissions: [entry()]
        }

  @types %{1 => :role, 2 => :user, 3 => :channel}

  @doc "Converts a raw guild application command permissions object into this struct."
  @spec from_raw(map()) :: t()
  def from_raw(%__MODULE__{} = parsed), do: parsed

  def from_raw(raw) when is_map(raw) do
    %__MODULE__{
      id: :maps.get("id", raw, nil),
      application_id: :maps.get("application_id", raw, nil),
      guild_id: :maps.get("guild_id", raw, nil),
      permissions:
        Enum.map(:maps.get("permissions", raw, nil) || [], fn p ->
          %{id: p["id"], type: Map.get(@types, p["type"], p["type"]), permission: p["permission"]}
        end)
    }
  end

  @doc "Whether these permissions apply to every command of the app rather than one."
  @spec app_wide?(t()) :: boolean()
  def app_wide?(%__MODULE__{id: id, application_id: app_id}), do: id == app_id

  @doc """
  Whether an entry targets `@everyone` — a role entry whose id is the guild id.

      iex> EDA.Command.Permissions.everyone?(%{id: "10", type: :role}, "10")
      true
  """
  @spec everyone?(entry(), String.t()) :: boolean()
  def everyone?(%{id: id, type: :role}, guild_id), do: id == to_string(guild_id)
  def everyone?(_entry, _guild_id), do: false

  @doc """
  Whether an entry targets every channel — a channel entry whose id is the guild id minus one.

      iex> EDA.Command.Permissions.all_channels?(%{id: "9", type: :channel}, "10")
      true
  """
  @spec all_channels?(entry(), String.t()) :: boolean()
  def all_channels?(%{id: id, type: :channel}, guild_id),
    do: id == Integer.to_string(String.to_integer(to_string(guild_id)) - 1)

  def all_channels?(_entry, _guild_id), do: false
end
