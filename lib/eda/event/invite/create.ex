defmodule EDA.Event.InviteCreate do
  @moduledoc """
  Sent when an invite is created. Delivers an `EDA.Invite`, not a struct of its own.

  The consumer receives `{:INVITE_CREATE, %EDA.Invite{}}` with every field Discord sent —
  `expires_at`, `created_at`, the target and the roles it grants among them, which the event
  used to drop — so `EDA.Invite.url/1` and the other invite functions take it as is. The roles
  arrive as `role_ids`; `roles` is `nil`. This module only parses the payload.
  """

  @doc "Parses the `INVITE_CREATE` payload into an `EDA.Invite`."
  @spec from_raw(map()) :: EDA.Invite.t()
  def from_raw(raw) when is_map(raw), do: EDA.Invite.from_raw(raw)
end
