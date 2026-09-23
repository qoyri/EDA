defmodule EDA.AuditLog.Change do
  @moduledoc "Represents a single change within an audit log entry."
  use EDA.Event.Access

  defstruct [:key, :old_value, :new_value]

  @type t :: %__MODULE__{
          key: String.t() | nil,
          old_value: term(),
          new_value: term()
        }

  @doc "Converts a raw change map into this struct."
  @spec from_raw(map()) :: t()
  def from_raw(%__MODULE__{} = parsed), do: parsed

  def from_raw(raw) when is_map(raw) do
    %__MODULE__{
      key: :maps.get("key", raw, nil),
      old_value: :maps.get("old_value", raw, nil),
      new_value: :maps.get("new_value", raw, nil)
    }
  end
end
