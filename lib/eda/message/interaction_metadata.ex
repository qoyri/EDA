defmodule EDA.Message.InteractionMetadata do
  @moduledoc """
  The interaction a message answers: who ran it, and, for a component or a modal, the message
  that was clicked (`interacted_message_id`) or the interaction that opened the modal
  (`triggering_interaction_metadata`).

  `type` uses the names of `EDA.Interaction.interaction_type/1` (`:command`, `:component`,
  `:modal_submit`…). `authorizing_integration_owners` is keyed `:guild_install` and
  `:user_install`, as on `EDA.Event.InteractionCreate`.
  """

  use EDA.Event.Access

  defstruct [
    :id,
    :type,
    :user,
    :authorizing_integration_owners,
    :original_response_message_id,
    :target_user,
    :target_message_id,
    :interacted_message_id,
    :triggering_interaction_metadata
  ]

  @type t :: %__MODULE__{
          id: String.t() | nil,
          type: atom() | integer() | nil,
          user: EDA.User.t() | nil,
          authorizing_integration_owners: %{optional(atom() | String.t()) => String.t()} | nil,
          original_response_message_id: String.t() | nil,
          target_user: EDA.User.t() | nil,
          target_message_id: String.t() | nil,
          interacted_message_id: String.t() | nil,
          triggering_interaction_metadata: t() | nil
        }

  @doc false
  @spec from_raw(map() | nil) :: t() | nil
  def from_raw(nil), do: nil

  def from_raw(%__MODULE__{} = parsed), do: parsed

  def from_raw(raw) when is_map(raw) do
    %__MODULE__{
      id: :maps.get("id", raw, nil),
      type: EDA.Event.InteractionCreate.type_name(:maps.get("type", raw, nil)),
      user: parse_user(:maps.get("user", raw, nil)),
      authorizing_integration_owners:
        EDA.Event.InteractionCreate.parse_owners(
          :maps.get("authorizing_integration_owners", raw, nil)
        ),
      original_response_message_id: :maps.get("original_response_message_id", raw, nil),
      target_user: parse_user(:maps.get("target_user", raw, nil)),
      target_message_id: :maps.get("target_message_id", raw, nil),
      interacted_message_id: :maps.get("interacted_message_id", raw, nil),
      triggering_interaction_metadata:
        from_raw(:maps.get("triggering_interaction_metadata", raw, nil))
    }
  end

  defp parse_user(nil), do: nil
  defp parse_user(raw), do: EDA.User.from_raw(raw)
end
