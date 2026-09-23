defmodule EDA.PermissionOverwrite do
  @moduledoc "Represents a Discord channel permission overwrite."
  use EDA.Event.Access

  @types %{0 => :role, 1 => :member}

  defstruct [:id, :type, :allow, :deny]

  @type t :: %__MODULE__{
          id: String.t() | nil,
          type: :role | :member | integer() | nil,
          allow: String.t() | nil,
          deny: String.t() | nil
        }

  @spec from_raw(map()) :: t()
  def from_raw(raw) when is_map(raw) do
    %__MODULE__{
      id: raw["id"],
      type: EDA.Enum.name(@types, raw["type"]),
      allow: raw["allow"],
      deny: raw["deny"]
    }
  end

  @doc """
  The integer Discord uses for a permission overwrite type, from its atom or the integer itself.
  """
  @spec type_value(atom() | integer()) :: integer()
  def type_value(value), do: EDA.Enum.value!(@types, value, "permission overwrite type")
end
