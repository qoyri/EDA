defmodule EDA.AuditLog.Entry.Options do
  @moduledoc """
  What an audit log entry adds for some actions: the channel and count of a bulk delete or a
  message pin, the days and members of a prune, the overwritten role or member of a permission
  change (`type` `:role` or `:member`, the name in `role_name`), the rule an AutoMod action came
  from, the application of a command permission change, the kind of integration removed, a
  voice channel's new status.

  Discord sends the counts and the overwrite type as strings; they are integers and atoms here.
  """

  use EDA.Event.Access

  defstruct [
    :application_id,
    :auto_moderation_rule_name,
    :auto_moderation_rule_trigger_type,
    :channel_id,
    :count,
    :delete_member_days,
    :id,
    :members_removed,
    :message_id,
    :role_name,
    :type,
    :integration_type,
    :status
  ]

  @type t :: %__MODULE__{
          application_id: String.t() | nil,
          auto_moderation_rule_name: String.t() | nil,
          auto_moderation_rule_trigger_type: atom() | integer() | nil,
          channel_id: String.t() | nil,
          count: non_neg_integer() | nil,
          delete_member_days: non_neg_integer() | nil,
          id: String.t() | nil,
          members_removed: non_neg_integer() | nil,
          message_id: String.t() | nil,
          role_name: String.t() | nil,
          type: :role | :member | String.t() | nil,
          integration_type: String.t() | nil,
          status: String.t() | nil
        }

  @overwrite_types %{"0" => :role, "1" => :member}

  @doc """
  An entry's options as Discord sends them.

      iex> EDA.AuditLog.Entry.Options.from_raw(%{"delete_member_days" => "7", "members_removed" => "12"})
      %EDA.AuditLog.Entry.Options{delete_member_days: 7, members_removed: 12}
      iex> EDA.AuditLog.Entry.Options.from_raw(%{"id" => "1", "type" => "0", "role_name" => "mod"})
      %EDA.AuditLog.Entry.Options{id: "1", type: :role, role_name: "mod"}
  """
  @spec from_raw(map() | nil) :: t() | nil
  def from_raw(nil), do: nil

  def from_raw(%__MODULE__{} = parsed), do: parsed

  def from_raw(raw) when is_map(raw) do
    %__MODULE__{
      application_id: :maps.get("application_id", raw, nil),
      auto_moderation_rule_name: :maps.get("auto_moderation_rule_name", raw, nil),
      auto_moderation_rule_trigger_type:
        :maps.get("auto_moderation_rule_trigger_type", raw, nil)
        |> integer()
        |> then(&EDA.Enum.name(EDA.AutoMod.trigger_types(), &1)),
      channel_id: :maps.get("channel_id", raw, nil),
      count: integer(:maps.get("count", raw, nil)),
      delete_member_days: integer(:maps.get("delete_member_days", raw, nil)),
      id: :maps.get("id", raw, nil),
      members_removed: integer(:maps.get("members_removed", raw, nil)),
      message_id: :maps.get("message_id", raw, nil),
      role_name: :maps.get("role_name", raw, nil),
      type: Map.get(@overwrite_types, :maps.get("type", raw, nil), :maps.get("type", raw, nil)),
      integration_type: :maps.get("integration_type", raw, nil),
      status: :maps.get("status", raw, nil)
    }
  end

  defp integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {int, ""} -> int
      _ -> value
    end
  end

  defp integer(value), do: value
end
