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

  def from_raw(raw) when is_map(raw) do
    %__MODULE__{
      id: raw["id"],
      name: raw["name"],
      icon: raw["icon"],
      owner_user_id: raw["owner_user_id"],
      members: raw["members"] && Enum.map(raw["members"], &EDA.Team.Member.from_raw/1)
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
end
