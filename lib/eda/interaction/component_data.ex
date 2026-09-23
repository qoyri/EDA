defmodule EDA.Interaction.ComponentData do
  @moduledoc """
  The `data` of a button click or a select menu choice: the `custom_id` the component was
  built with, its kind in `component_type` (`:button`, `:string_select`…), the `values` chosen
  in a select, and, for a user, role, mentionable or channel select, what they are in
  `resolved`.
  """

  use EDA.Event.Access

  defstruct [:custom_id, :component_type, :values, :resolved]

  @type t :: %__MODULE__{
          custom_id: String.t() | nil,
          component_type: EDA.Component.type() | nil,
          values: [String.t()] | nil,
          resolved: EDA.Resolved.t() | nil
        }

  @doc false
  @spec from_raw(map()) :: t()
  def from_raw(raw) when is_map(raw) do
    %__MODULE__{
      custom_id: raw["custom_id"],
      component_type: EDA.Component.type_name(raw["component_type"]),
      values: raw["values"],
      resolved: EDA.Resolved.from_raw(raw["resolved"])
    }
  end
end
