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
  def from_raw(%__MODULE__{} = parsed), do: parsed

  def from_raw(raw) when is_map(raw) do
    %__MODULE__{
      id: :maps.get("id", raw, nil),
      type: EDA.Enum.name(@types, :maps.get("type", raw, nil)),
      allow: :maps.get("allow", raw, nil),
      deny: :maps.get("deny", raw, nil)
    }
  end

  @doc """
  The integer Discord uses for a permission overwrite type, from its atom or the integer itself.
  """
  @spec type_value(atom() | integer() | nil) :: integer() | nil
  def type_value(value), do: EDA.Enum.value!(@types, value, "permission overwrite type")
end
