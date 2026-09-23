defmodule EDA.InviteCreateEventTest do
  @moduledoc """
  `INVITE_CREATE` delivers an `EDA.Invite`.

  Its struct used to keep 8 fields and drop `expires_at`, `created_at`, the target and the roles
  the invite grants — what a bot tracking its invites needs. Payload per the gateway events
  reference.
  """

  use ExUnit.Case, async: true

  @payload %{
    "channel_id" => "1",
    "code" => "abc123",
    "created_at" => "2026-09-23T10:00:00.000000+00:00",
    "expires_at" => "2026-09-24T10:00:00.000000+00:00",
    "guild_id" => "2",
    "inviter" => %{"id" => "3", "username" => "someone"},
    "max_age" => 86_400,
    "max_uses" => 5,
    "target_type" => 1,
    "target_user" => %{"id" => "4", "username" => "streamer"},
    "temporary" => false,
    "uses" => 0,
    "role_ids" => ["5", "6"]
  }

  test "is an EDA.Invite, with what the event used to drop" do
    invite = EDA.Event.from_raw("INVITE_CREATE", @payload)

    assert %EDA.Invite{code: "abc123", guild_id: "2", channel_id: "1"} = invite
    assert invite.expires_at == "2026-09-24T10:00:00.000000+00:00"
    assert invite.created_at == "2026-09-23T10:00:00.000000+00:00"
    assert EDA.Invite.target_type(invite) == :stream
    assert %EDA.User{username: "streamer"} = invite.target_user
    assert invite.role_ids == ["5", "6"]
  end

  test "the invite functions take it as is" do
    invite = EDA.Event.from_raw("INVITE_CREATE", @payload)

    assert EDA.Invite.url(invite) == "https://discord.gg/abc123"
    refute EDA.Invite.permanent?(invite)
  end

  test "role_ids is filled from the partial roles the REST routes send" do
    invite = EDA.Invite.from_raw(%{"code" => "x", "roles" => [%{"id" => "7", "name" => "Guest"}]})

    assert [%EDA.Role{id: "7"}] = invite.roles
    assert invite.role_ids == ["7"]
  end
end
