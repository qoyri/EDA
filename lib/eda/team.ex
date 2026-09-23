defmodule EDA.Team do
  @moduledoc """
  The developer team that owns an application: its name, icon, owner and `members`, each an
  `EDA.Team.Member`.
  """

  use EDA.Event.Access

  defstruct [:id, :name, :icon, :owner_user_id, :members]

  @type t :: %__MODULE__{
          id: String.t() | nil,
          name: String.t() | nil,
          icon: String.t() | nil,
          owner_user_id: String.t() | nil,
          members: [EDA.Team.Member.t()] | nil
        }

  @doc false
  @spec from_raw(map() | nil) :: t() | nil
  def from_raw(nil), do: nil

  def from_raw(%__MODULE__{} = parsed), do: parsed

  def from_raw(raw) when is_map(raw) do
    %__MODULE__{
      id: :maps.get("id", raw, nil),
      name: :maps.get("name", raw, nil),
      icon: :maps.get("icon", raw, nil),
      owner_user_id: :maps.get("owner_user_id", raw, nil),
      members:
        :maps.get("members", raw, nil) &&
          Enum.map(:maps.get("members", raw, nil), &EDA.Team.Member.from_raw/1)
    }
  end

  @doc """
  The URL of the team's icon, or `nil`. Takes `:format` and `:size`.

      iex> EDA.Team.icon_url(%EDA.Team{id: "2", icon: "t"})
      "https://cdn.discordapp.com/team-icons/2/t.png"
  """
  @spec icon_url(t(), keyword()) :: String.t() | nil
  def icon_url(team, opts \\ [])
  def icon_url(%__MODULE__{icon: nil}, _opts), do: nil

  def icon_url(%__MODULE__{id: id, icon: icon}, opts),
    do: EDA.CDN.url("team-icons/#{id}/#{icon}", false, opts)

  @doc """
  Whether a user is on the team, having accepted its invitation. Takes an `EDA.User` or an id.

      iex> team = %EDA.Team{members: [%EDA.Team.Member{user: %EDA.User{id: "4"}, membership_state: :accepted}]}
      iex> EDA.Team.member?(team, "4")
      true
  """
  @spec member?(t(), EDA.User.t() | String.t()) :: boolean()
  def member?(team, %EDA.User{id: id}), do: member?(team, id)

  def member?(%__MODULE__{members: members}, user_id) do
    Enum.any?(
      members || [],
      &(&1.membership_state == :accepted and &1.user && &1.user.id == user_id)
    )
  end
end
