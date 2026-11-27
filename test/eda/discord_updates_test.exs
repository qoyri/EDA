defmodule EDA.DiscordUpdatesTest do
  @moduledoc """
  Small additions that follow Discord's change log: audit log actions, error codes, and the
  voice opcode that chooses whose audio is sent.
  """
  use ExUnit.Case, async: true

  describe "audit log" do
    test "reordering channels and roles has its own actions" do
      assert EDA.AuditLog.action_name(16) == :channel_position_update
      assert EDA.AuditLog.action_name(33) == :role_position_update
      assert EDA.AuditLog.action_type(:channel_position_update) == 16
      assert EDA.AuditLog.action_type(:role_position_update) == 33
    end

    test "a reorder entry counts the positions it changed" do
      entry =
        EDA.AuditLog.Entry.from_raw(%{
          "id" => "1",
          "user_id" => "2",
          "action_type" => 33,
          "options" => %{"count" => "4"}
        })

      assert entry.action_type == :role_position_update
      assert entry.options.count == 4
    end
  end

  describe "error codes" do
    test "the codes Discord added are named" do
      assert EDA.Error.name(50_270) == :invite_expired
      assert EDA.Error.invite_expired() == 50_270
      assert EDA.Error.name(50_278) == :no_mutual_guilds
      assert EDA.Error.name(40_009) == :one_parent_change_at_a_time
      assert EDA.Error.name(40_114) == :invite_target_users_already_processing
      assert EDA.Error.name(40_115) == :invite_target_users_file_not_processed
      assert EDA.Error.name(30_084) == :max_invite_target_users
      assert EDA.Error.name(20_015) == :premium_subscription_required
      assert EDA.Error.name(50_167) == :cannot_send_voice_effect_while_muted
      assert EDA.Error.name(340_015) == :server_join_limited
    end

    test "every name has one code, and every constant returns its own" do
      all = EDA.Error.all()
      names = Enum.map(all, fn {_code, {name, _message}} -> name end)

      assert names == Enum.uniq(names)

      for {code, {name, _message}} <- all, function_exported?(EDA.Error, name, 0) do
        assert apply(EDA.Error, name, []) == code
      end
    end
  end

  describe "media sink wants" do
    test "the payload names each SSRC, and `any` for the rest" do
      assert EDA.Voice.Payload.media_sink_wants(%{12 => 100, any: 0}) ==
               %{op: 15, d: %{"any" => 0, "12" => 100}}

      assert Jason.decode!(Jason.encode!(EDA.Voice.Payload.media_sink_wants(%{2 => 0, any: 100}))) ==
               %{"op" => 15, "d" => %{"any" => 100, "2" => 0}}
    end

    test "without a voice session there is nothing to tell" do
      assert {:error, :not_connected} =
               EDA.Voice.media_sink_wants("no_such_guild_sink", %{any: 0})
    end

    test "a key that is not an SSRC, or a value outside 0..100, is refused" do
      assert_raise ArgumentError, ~r/expected :any or an SSRC/, fn ->
        EDA.Voice.media_sink_wants("g", %{"any" => 0})
      end

      assert_raise ArgumentError, ~r/0\.\.100/, fn ->
        EDA.Voice.media_sink_wants("g", %{any: 101})
      end

      assert_raise ArgumentError, fn -> EDA.Voice.media_sink_wants("g", %{-1 => 0}) end
    end
  end
end
