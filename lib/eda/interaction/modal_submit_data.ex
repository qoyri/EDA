defmodule EDA.Interaction.ModalSubmitData do
  @moduledoc """
  The `data` of a submitted modal: its `custom_id`, the `components` as `EDA.Component`
  structs carrying what the user entered, and the uploaded files or selected entities in
  `resolved`.

  `EDA.Modal.get_values/1` reads the values out of the tree, by custom id.
  """

  use EDA.Event.Access

  defstruct [:custom_id, :components, :resolved]

  @type t :: %__MODULE__{
          custom_id: String.t() | nil,
          components: [EDA.Component.t()] | nil,
          resolved: EDA.Resolved.t() | nil
        }

  @doc false
  @spec from_raw(map()) :: t()
  def from_raw(raw) when is_map(raw) do
    %__MODULE__{
      custom_id: raw["custom_id"],
      components: EDA.Component.parse_list(raw["components"]),
      resolved: EDA.Resolved.from_raw(raw["resolved"])
    }
  end
end
