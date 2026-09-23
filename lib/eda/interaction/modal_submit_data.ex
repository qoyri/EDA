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
  def from_raw(%__MODULE__{} = parsed), do: parsed

  def from_raw(raw) when is_map(raw) do
    %__MODULE__{
      custom_id: :maps.get("custom_id", raw, nil),
      components: EDA.Component.parse_list(:maps.get("components", raw, nil)),
      resolved: EDA.Resolved.from_raw(:maps.get("resolved", raw, nil))
    }
  end
end
