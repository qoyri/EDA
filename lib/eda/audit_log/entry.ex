defmodule EDA.AuditLog.Entry do
  @moduledoc """
  A single audit log entry, from `EDA.API.AuditLog` or the `GUILD_AUDIT_LOG_ENTRY_CREATE`
  event, which adds its `guild_id`.

  `changes` are `EDA.AuditLog.Change` structs, `options` an `EDA.AuditLog.Entry.Options`.
  """
  use EDA.Event.Access

  defstruct [:id, :guild_id, :target_id, :user_id, :action_type, :changes, :reason, :options]

  @type t :: %__MODULE__{
          id: String.t() | nil,
          guild_id: String.t() | nil,
          target_id: String.t() | nil,
          user_id: String.t() | nil,
          action_type: atom() | integer() | nil,
          changes: [EDA.AuditLog.Change.t()] | nil,
          reason: String.t() | nil,
          options: EDA.AuditLog.Entry.Options.t() | nil
        }

  @doc "Converts a raw audit log entry map into this struct. Parses changes into Change structs."
  @spec from_raw(map()) :: t()
  def from_raw(%__MODULE__{} = parsed), do: parsed

  def from_raw(raw) when is_map(raw) do
    changes =
      case :maps.get("changes", raw, nil) do
        nil -> nil
        list when is_list(list) -> Enum.map(list, &EDA.AuditLog.Change.from_raw/1)
      end

    %__MODULE__{
      id: :maps.get("id", raw, nil),
      guild_id: :maps.get("guild_id", raw, nil),
      target_id: :maps.get("target_id", raw, nil),
      user_id: :maps.get("user_id", raw, nil),
      action_type: EDA.Enum.name(EDA.AuditLog.action_types(), :maps.get("action_type", raw, nil)),
      changes: changes,
      reason: :maps.get("reason", raw, nil),
      options: EDA.AuditLog.Entry.Options.from_raw(:maps.get("options", raw, nil))
    }
  end

  @doc """
  The change of one key in the entry, as an `EDA.AuditLog.Change`, or `nil`.

      iex> entry = EDA.AuditLog.Entry.from_raw(%{"changes" => [%{"key" => "nick", "old_value" => "a", "new_value" => "b"}]})
      iex> EDA.AuditLog.Entry.change(entry, "nick").new_value
      "b"
  """
  @spec change(t(), String.t() | atom()) :: EDA.AuditLog.Change.t() | nil
  def change(%__MODULE__{changes: changes}, key),
    do: Enum.find(changes || [], &(&1.key == to_string(key)))
end
