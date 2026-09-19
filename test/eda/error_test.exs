defmodule EDA.ErrorTest do
  use ExUnit.Case, async: true

  alias EDA.Error

  describe "name/1" do
    test "returns atom for known codes" do
      assert Error.name(0) == :general_error
      assert Error.name(10_003) == :unknown_channel
      assert Error.name(50_013) == :missing_permissions
      assert Error.name(530_007) == :invalid_client_secret
    end

    test "returns nil for unknown code" do
      assert Error.name(99_999) == nil
    end
  end

  describe "code/1" do
    test "returns integer for known atoms" do
      assert Error.code(:general_error) == 0
      assert Error.code(:unknown_channel) == 10_003
      assert Error.code(:missing_permissions) == 50_013
      assert Error.code(:invalid_client_secret) == 530_007
    end

    test "returns nil for unknown atom" do
      assert Error.code(:not_a_real_error) == nil
    end
  end

  describe "message/1" do
    test "returns description for known codes" do
      assert Error.message(0) ==
               "General error (such as a malformed request body, amongst other things)"

      assert Error.message(50_013) == "You lack permissions to perform that action"
      assert Error.message(10_003) == "Unknown channel"
    end

    test "returns nil for unknown code" do
      assert Error.message(99_999) == nil
    end
  end

  describe "known?/1" do
    test "returns true for known codes" do
      assert Error.known?(0)
      assert Error.known?(50_013)
      assert Error.known?(530_007)
    end

    test "returns false for unknown codes" do
      refute Error.known?(99_999)
      refute Error.known?(-1)
    end
  end

  describe "all/0" do
    test "returns non-empty map" do
      all = Error.all()
      assert is_map(all)
      assert map_size(all) > 0
    end

    test "entries have correct format {integer => {atom, string}}" do
      for {code, {name, msg}} <- Error.all() do
        assert is_integer(code), "key #{inspect(code)} is not an integer"
        assert is_atom(name), "name #{inspect(name)} for code #{code} is not an atom"
        assert is_binary(msg), "message for code #{code} is not a string"
      end
    end
  end

  describe "named constants" do
    test "return correct integer values" do
      assert Error.unknown_channel() == 10_003
      assert Error.missing_permissions() == 50_013
      assert Error.max_roles() == 30_005
      assert Error.unauthorized() == 40_001
      assert Error.two_factor_required() == 60_003
      assert Error.reaction_blocked() == 90_001
      assert Error.thread_locked() == 160_005
      assert Error.invalid_client_secret() == 530_007
    end
  end

  describe "the message-reference codes" do
    # 160009, 160010 and 160014 all reject a message that points at another message, and
    # they arrive as ordinary {:error, %{code: _}} tuples from any create/forward call.
    test "forwarding a message the bot cannot read" do
      assert Error.cannot_forward_unreadable_message() == 160_014
      assert Error.name(160_014) == :cannot_forward_unreadable_message

      assert Error.message(160_014) ==
               "You cannot forward a message whose content you cannot read"
    end

    test "referencing without read message history" do
      assert Error.cannot_reference_without_read_history() == 160_009
      assert Error.name(160_009) == :cannot_reference_without_read_history
    end

    test "referencing a message from an NSFW channel" do
      assert Error.nsfw_message_reference_not_allowed() == 160_010
      assert Error.name(160_010) == :nsfw_message_reference_not_allowed
    end

    test "they round-trip like every other code" do
      for code <- [160_009, 160_010, 160_014] do
        assert Error.known?(code)
        assert Error.code(Error.name(code)) == code
      end
    end
  end

  describe "bidirectionality" do
    test "code(name(x)) == x for sample of codes" do
      sample = [
        0,
        10_003,
        20_001,
        30_005,
        40_001,
        50_013,
        60_003,
        80_004,
        90_001,
        110_001,
        130_000,
        150_006,
        160_005,
        160_014,
        170_001,
        180_000,
        200_000,
        220_001,
        240_000,
        350_000,
        400_001,
        500_000,
        520_000,
        530_007
      ]

      for code <- sample do
        assert Error.code(Error.name(code)) == code,
               "roundtrip failed for code #{code}"
      end
    end
  end

  describe "coverage per category" do
    test "at least one code per range is known" do
      ranges = [
        {0, "General"},
        {10_001, "Unknown Resource (10xxx)"},
        {20_001, "Action Prohibition (20xxx)"},
        {30_001, "Maximum Limits (30xxx)"},
        {40_001, "Authorization (40xxx)"},
        {50_001, "Invalid State (50xxx)"},
        {60_003, "Two-Factor (60xxx)"},
        {80_004, "User Lookup (80xxx)"},
        {90_001, "Reactions (90xxx)"},
        {110_001, "Application Availability (110xxx)"},
        {130_000, "API Overload (130xxx)"},
        {150_006, "Stage (150xxx)"},
        {160_002, "Threads (160xxx)"},
        {170_001, "Sticker Validation (170xxx)"},
        {180_000, "Scheduled Events (180xxx)"},
        {200_000, "Auto Moderation (200xxx)"},
        {220_001, "Webhook Forum (220xxx)"},
        {240_000, "Harmful Links (240xxx)"},
        {350_000, "Onboarding (350xxx)"},
        {400_001, "File Uploads (400xxx)"},
        {500_000, "Bans (500xxx)"},
        {520_000, "Polls (520xxx)"},
        {530_000, "Provisional Accounts (530xxx)"}
      ]

      for {code, category} <- ranges do
        assert Error.known?(code), "missing code #{code} in category #{category}"
      end
    end
  end
end
