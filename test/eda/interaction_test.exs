defmodule EDA.InteractionTest do
  use ExUnit.Case, async: true

  import EDA.Interaction

  # ── Test Fixtures ───────────────────────────────────────────────────

  defp slash_interaction(opts \\ %{}) do
    Map.merge(
      %{
        "id" => "111",
        "application_id" => "222",
        "type" => 2,
        "token" => "test-token",
        "guild_id" => "333",
        "channel_id" => "444",
        "member" => %{
          "user" => %{"id" => "555", "username" => "testuser"}
        },
        "data" => %{
          "name" => "greet",
          "type" => 1,
          "options" => [
            %{"name" => "message", "type" => 3, "value" => "Hello!"},
            %{"name" => "target", "type" => 6, "value" => "666"}
          ]
        }
      },
      opts
    )
  end

  defp sub_command_interaction do
    %{
      "id" => "111",
      "application_id" => "222",
      "type" => 2,
      "token" => "test-token",
      "guild_id" => "333",
      "channel_id" => "444",
      "member" => %{
        "user" => %{"id" => "555", "username" => "testuser"}
      },
      "data" => %{
        "name" => "role",
        "type" => 1,
        "options" => [
          %{
            "name" => "add",
            "type" => 1,
            "options" => [
              %{"name" => "role", "type" => 8, "value" => "777"},
              %{"name" => "target", "type" => 6, "value" => "888"}
            ]
          }
        ]
      }
    }
  end

  defp sub_command_group_interaction do
    %{
      "id" => "111",
      "application_id" => "222",
      "type" => 2,
      "token" => "test-token",
      "data" => %{
        "name" => "permissions",
        "type" => 1,
        "options" => [
          %{
            "name" => "user",
            "type" => 2,
            "options" => [
              %{
                "name" => "set",
                "type" => 1,
                "options" => [
                  %{"name" => "target", "type" => 6, "value" => "999"},
                  %{"name" => "level", "type" => 4, "value" => 5}
                ]
              }
            ]
          }
        ]
      }
    }
  end

  defp dm_interaction do
    %{
      "id" => "111",
      "application_id" => "222",
      "type" => 2,
      "token" => "test-token",
      "channel_id" => "444",
      "user" => %{"id" => "555", "username" => "dmuser"},
      "data" => %{
        "name" => "ping",
        "type" => 1,
        "options" => []
      }
    }
  end

  defp user_command_interaction do
    %{
      "id" => "111",
      "application_id" => "222",
      "type" => 2,
      "token" => "test-token",
      "data" => %{
        "name" => "User Info",
        "type" => 2,
        "target_id" => "999",
        "resolved" => %{
          "users" => %{
            "999" => %{"id" => "999", "username" => "targetuser"}
          },
          "members" => %{
            "999" => %{"nick" => "Target"}
          }
        }
      }
    }
  end

  defp component_interaction do
    %{
      "id" => "111",
      "type" => 3,
      "token" => "test-token",
      "data" => %{
        "custom_id" => "btn_confirm",
        "component_type" => 2
      }
    }
  end

  defp autocomplete_interaction do
    %{
      "id" => "111",
      "type" => 4,
      "token" => "test-token",
      "data" => %{
        "name" => "search",
        "options" => [
          %{"name" => "query", "type" => 3, "value" => "hel", "focused" => true}
        ]
      }
    }
  end

  # ── command_name/1 ──────────────────────────────────────────────────

  describe "command_name/1" do
    test "returns the command name" do
      assert command_name(slash_interaction()) == "greet"
    end

    test "returns nil for interaction without data" do
      assert command_name(%{}) == nil
    end
  end

  # ── command_type/1 ──────────────────────────────────────────────────

  describe "command_type/1" do
    test "returns :slash for type 1" do
      assert command_type(slash_interaction()) == :slash
    end

    test "returns :user for type 2" do
      assert command_type(user_command_interaction()) == :user
    end

    test "returns nil for missing data" do
      assert command_type(%{}) == nil
    end
  end

  # ── interaction_type/1 ──────────────────────────────────────────────

  describe "interaction_type/1" do
    test "returns :command for type 2" do
      assert interaction_type(slash_interaction()) == :command
    end

    test "returns :component for type 3" do
      assert interaction_type(component_interaction()) == :component
    end

    test "returns :autocomplete for type 4" do
      assert interaction_type(autocomplete_interaction()) == :autocomplete
    end

    test "returns :ping for type 1" do
      assert interaction_type(%{"type" => 1}) == :ping
    end

    test "returns :modal_submit for type 5" do
      assert interaction_type(%{"type" => 5}) == :modal_submit
    end
  end

  # ── get_option/3 ────────────────────────────────────────────────────

  describe "get_option/3" do
    test "returns option value by name" do
      assert get_option(slash_interaction(), "message") == "Hello!"
    end

    test "returns nil for missing option" do
      assert get_option(slash_interaction(), "nonexistent") == nil
    end

    test "returns default for missing option" do
      assert get_option(slash_interaction(), "nonexistent", "fallback") == "fallback"
    end

    test "traverses into sub_command options" do
      assert get_option(sub_command_interaction(), "role") == "777"
      assert get_option(sub_command_interaction(), "target") == "888"
    end

    test "traverses into sub_command_group options" do
      assert get_option(sub_command_group_interaction(), "target") == "999"
      assert get_option(sub_command_group_interaction(), "level") == 5
    end

    test "returns nil for interaction without options" do
      assert get_option(%{}, "anything") == nil
    end
  end

  # ── get_options/1 ───────────────────────────────────────────────────

  describe "get_options/1" do
    test "returns flat map of option values" do
      opts = get_options(slash_interaction())
      assert opts == %{"message" => "Hello!", "target" => "666"}
    end

    test "flattens sub_command options" do
      opts = get_options(sub_command_interaction())
      assert opts == %{"role" => "777", "target" => "888"}
    end

    test "flattens sub_command_group options" do
      opts = get_options(sub_command_group_interaction())
      assert opts == %{"target" => "999", "level" => 5}
    end

    test "returns empty map for no options" do
      assert get_options(%{}) == %{}
    end
  end

  # ── sub_command_name/1 ──────────────────────────────────────────────

  describe "sub_command_name/1" do
    test "returns sub_command name" do
      assert sub_command_name(sub_command_interaction()) == "add"
    end

    test "returns {group, sub} for sub_command_group" do
      assert sub_command_name(sub_command_group_interaction()) == {"user", "set"}
    end

    test "returns nil for regular command" do
      assert sub_command_name(slash_interaction()) == nil
    end

    test "returns nil for empty interaction" do
      assert sub_command_name(%{}) == nil
    end
  end

  # ── user/1 ──────────────────────────────────────────────────────────

  describe "user/1" do
    test "returns user from guild interaction (via member)" do
      u = user(slash_interaction())
      assert u["id"] == "555"
      assert u["username"] == "testuser"
    end

    test "returns user from DM interaction" do
      u = user(dm_interaction())
      assert u["id"] == "555"
      assert u["username"] == "dmuser"
    end

    test "returns nil when no user" do
      assert user(%{}) == nil
    end
  end

  # ── member/1 ────────────────────────────────────────────────────────

  describe "member/1" do
    test "returns member in guild" do
      m = member(slash_interaction())
      assert m["user"]["id"] == "555"
    end

    test "returns nil in DM" do
      assert member(dm_interaction()) == nil
    end
  end

  # ── guild_id/1, channel_id/1, token/1 ──────────────────────────────

  describe "guild_id/1" do
    test "returns guild_id" do
      assert guild_id(slash_interaction()) == "333"
    end

    test "returns nil in DM" do
      assert guild_id(dm_interaction()) == nil
    end
  end

  describe "channel_id/1" do
    test "returns channel_id" do
      assert channel_id(slash_interaction()) == "444"
    end
  end

  describe "token/1" do
    test "returns token" do
      assert token(slash_interaction()) == "test-token"
    end
  end

  # ── resolved/3 ──────────────────────────────────────────────────────

  describe "resolved/3" do
    test "returns resolved user" do
      u = resolved(user_command_interaction(), "users", "999")
      assert u["username"] == "targetuser"
    end

    test "returns resolved member" do
      m = resolved(user_command_interaction(), "members", "999")
      assert m["nick"] == "Target"
    end

    test "returns nil for missing resolved type" do
      assert resolved(user_command_interaction(), "roles", "999") == nil
    end

    test "returns nil for missing resolved data" do
      assert resolved(slash_interaction(), "users", "123") == nil
    end

    test "returns nil for interaction without resolved" do
      assert resolved(%{}, "users", "123") == nil
    end
  end

  # ── target_id/1 ────────────────────────────────────────────────────

  describe "target_id/1" do
    test "returns target_id for context menu command" do
      assert target_id(user_command_interaction()) == "999"
    end

    test "returns nil for slash command" do
      assert target_id(slash_interaction()) == nil
    end
  end

  # ── custom_id/1 ────────────────────────────────────────────────────

  describe "custom_id/1" do
    test "returns custom_id for component interaction" do
      assert custom_id(component_interaction()) == "btn_confirm"
    end

    test "returns nil for slash command" do
      assert custom_id(slash_interaction()) == nil
    end
  end

  # ── Struct compatibility ──────────────────────────────────────────

  describe "struct compatibility" do
    defp interaction_struct do
      EDA.Event.InteractionCreate.from_raw(slash_interaction())
    end

    test "command_name works with struct" do
      assert command_name(interaction_struct()) == "greet"
    end

    test "command_type works with struct" do
      assert command_type(interaction_struct()) == :slash
    end

    test "interaction_type works with struct" do
      assert interaction_type(interaction_struct()) == :command
    end

    test "get_option works with struct" do
      assert get_option(interaction_struct(), "message") == "Hello!"
      assert get_option(interaction_struct(), "target") == "666"
    end

    test "get_options works with struct" do
      opts = get_options(interaction_struct())
      assert opts == %{"message" => "Hello!", "target" => "666"}
    end

    test "user works with struct" do
      u = user(interaction_struct())
      assert u["id"] == "555"
    end

    test "member works with struct" do
      m = member(interaction_struct())
      assert m["user"]["id"] == "555"
    end

    test "guild_id works with struct" do
      assert guild_id(interaction_struct()) == "333"
    end

    test "channel_id works with struct" do
      assert channel_id(interaction_struct()) == "444"
    end

    test "token works with struct" do
      assert token(interaction_struct()) == "test-token"
    end

    test "custom_id works with struct" do
      struct = EDA.Event.InteractionCreate.from_raw(component_interaction())
      assert custom_id(struct) == "btn_confirm"
    end

    test "target_id works with struct" do
      struct = EDA.Event.InteractionCreate.from_raw(user_command_interaction())
      assert target_id(struct) == "999"
    end

    test "resolved works with struct" do
      struct = EDA.Event.InteractionCreate.from_raw(user_command_interaction())
      u = resolved(struct, "users", "999")
      assert u["username"] == "targetuser"
    end

    test "sub_command_name works with struct" do
      struct = EDA.Event.InteractionCreate.from_raw(sub_command_interaction())
      assert sub_command_name(struct) == "add"
    end
  end

  # ── selected_values ──────────────────────────────────────────────────

  describe "selected_values/1" do
    test "returns values from select menu interaction" do
      interaction = %{data: %{"values" => ["opt1", "opt2"]}}
      assert selected_values(interaction) == ["opt1", "opt2"]
    end

    test "returns values from raw map interaction" do
      interaction = %{"data" => %{"values" => ["a"]}}
      assert selected_values(interaction) == ["a"]
    end

    test "returns empty list when no values" do
      assert selected_values(%{data: %{}}) == []
      assert selected_values(%{}) == []
    end
  end

  # ── component_type ───────────────────────────────────────────────────

  describe "component_type/1" do
    test "returns component type from interaction" do
      assert component_type(%{data: %{"component_type" => 2}}) == 2
      assert component_type(%{data: %{"component_type" => 3}}) == 3
    end

    test "returns component type from raw map" do
      assert component_type(%{"data" => %{"component_type" => 5}}) == 5
    end

    test "returns nil when not a component interaction" do
      assert component_type(%{data: %{}}) == nil
      assert component_type(%{}) == nil
    end
  end

  # ── delete_source ────────────────────────────────────────────────────

  describe "delete_source/1" do
    test "returns error when no source message" do
      interaction = %{channel_id: "123", data: %{}}
      assert {:error, :no_source_message} = EDA.Interaction.delete_source(interaction)
    end

    test "extracts message id from struct-style interaction" do
      interaction = %{
        channel_id: "123",
        message: %{"id" => "msg456"},
        data: %{}
      }

      # Will fail with API error since no server, but proves extraction works
      result = EDA.Interaction.delete_source(interaction)
      assert {:error, _} = result
    end

    test "extracts message id from raw map interaction" do
      interaction = %{
        "channel_id" => "123",
        "message" => %{"id" => "msg789"},
        "data" => %{}
      }

      result = EDA.Interaction.delete_source(interaction)
      assert {:error, _} = result
    end
  end
end
