defmodule EDA.Interaction.CommandData do
  @moduledoc """
  The `data` of a command interaction, or of its autocomplete: the command run (`id`, `name`,
  `type`), the `options` filled, the users, channels, roles and attachments they point to in
  `resolved`, and, for a context menu command, the user or message clicked in `target_id`.

  `type` is `:slash`, `:user` or `:message`, the names `EDA.Command` uses, or
  `:primary_entry_point` for an activity's launch command. `guild_id` is set for a command
  registered in a guild.
  """

  use EDA.Event.Access

  defstruct [:id, :name, :type, :resolved, :options, :guild_id, :target_id]

  @type t :: %__MODULE__{
          id: String.t() | nil,
          name: String.t() | nil,
          type: :slash | :user | :message | :primary_entry_point | integer() | nil,
          resolved: EDA.Resolved.t() | nil,
          options: [EDA.Interaction.Option.t()] | nil,
          guild_id: String.t() | nil,
          target_id: String.t() | nil
        }

  @types %{1 => :slash, 2 => :user, 3 => :message, 4 => :primary_entry_point}

  @doc false
  @spec from_raw(map()) :: t()
  def from_raw(raw) when is_map(raw) do
    %__MODULE__{
      id: raw["id"],
      name: raw["name"],
      type: EDA.Enum.name(@types, raw["type"]),
      resolved: EDA.Resolved.from_raw(raw["resolved"]),
      options: EDA.Interaction.Option.parse(raw["options"]),
      guild_id: raw["guild_id"],
      target_id: raw["target_id"]
    }
  end
end
