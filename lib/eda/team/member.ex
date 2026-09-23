defmodule EDA.Team.Member do
  @moduledoc """
  A member of a developer team: the `user`, their `role` (`:admin`, `:developer` or
  `:read_only`; the owner is the team's `owner_user_id`), and whether they have accepted the
  invitation (`membership_state` `:invited` or `:accepted`).
  """

  use EDA.Event.Access

  defstruct [:team_id, :user, :role, :membership_state]

  @type t :: %__MODULE__{
          team_id: String.t() | nil,
          user: EDA.User.t() | nil,
          role: :admin | :developer | :read_only | String.t() | nil,
          membership_state: :invited | :accepted | integer() | nil
        }

  @roles %{"admin" => :admin, "developer" => :developer, "read_only" => :read_only}
  @membership_states %{1 => :invited, 2 => :accepted}

  @doc false
  @spec from_raw(map()) :: t()
  def from_raw(raw) when is_map(raw) do
    %__MODULE__{
      team_id: raw["team_id"],
      user: raw["user"] && EDA.User.from_raw(raw["user"]),
      role: Map.get(@roles, raw["role"], raw["role"]),
      membership_state: EDA.Enum.name(@membership_states, raw["membership_state"])
    }
  end
end
