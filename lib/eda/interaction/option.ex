defmodule EDA.Interaction.Option do
  @moduledoc """
  An option a user filled in a slash command, or the subcommand they chose.

  `type` is Discord's name lowercased (`:string`, `:integer`, `:user`, `:sub_command`…). A
  subcommand or group has no `value` and holds its own `options`; during autocomplete, the
  option being typed has `focused: true` and its partial `value`, always a string.

  `EDA.Interaction.get_option/3` and `get_options/1` read the values without walking the tree.
  """

  use EDA.Event.Access

  defstruct [:name, :type, :value, :options, focused: false]

  @type type ::
          :sub_command
          | :sub_command_group
          | :string
          | :integer
          | :boolean
          | :user
          | :channel
          | :role
          | :mentionable
          | :number
          | :attachment
          | integer()

  @type t :: %__MODULE__{
          name: String.t() | nil,
          type: type() | nil,
          value: String.t() | integer() | float() | boolean() | nil,
          options: [t()] | nil,
          focused: boolean()
        }

  @doc false
  @spec from_raw(map()) :: t()
  def from_raw(raw) when is_map(raw) do
    %__MODULE__{
      name: raw["name"],
      type: EDA.Command.Option.type_name(raw["type"]),
      value: raw["value"],
      options: parse(raw["options"]),
      focused: raw["focused"] == true
    }
  end

  @doc false
  def parse(nil), do: nil
  def parse(list) when is_list(list), do: Enum.map(list, &from_raw/1)
end
