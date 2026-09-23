defmodule EDA.Interaction.DataTest do
  @moduledoc """
  An interaction's `data` is a struct for each of its three shapes, and the `EDA.Interaction`
  and `EDA.Modal` helpers read it whether they get the event or the raw interaction map.
  """

  use ExUnit.Case, async: true

  alias EDA.Interaction
  alias EDA.Interaction.{CommandData, ComponentData, ModalSubmitData, Option}

  defp event(raw), do: EDA.Event.from_raw("INTERACTION_CREATE", raw)

  @command %{
    "id" => "1",
    "type" => 2,
    "token" => "t",
    "data" => %{
      "id" => "10",
      "name" => "ticket",
      "type" => 1,
      "options" => [
        %{
          "name" => "open",
          "type" => 1,
          "options" => [
            %{"name" => "reason", "type" => 3, "value" => "bug"},
            %{"name" => "urgent", "type" => 5, "value" => false},
            %{"name" => "for", "type" => 6, "value" => "42"}
          ]
        }
      ],
      "resolved" => %{
        "users" => %{"42" => %{"id" => "42", "username" => "ann"}},
        "members" => %{"42" => %{"nick" => "Annie", "roles" => [], "permissions" => "8"}},
        "channels" => %{
          "7" => %{"id" => "7", "type" => 0, "name" => "general", "app_permissions" => "2048"}
        }
      }
    }
  }

  test "a command's data, down to its options and resolved entities" do
    interaction = event(@command)

    assert %CommandData{name: "ticket", type: :slash, options: [open]} = interaction.data
    assert %Option{type: :sub_command, name: "open", options: [reason, urgent, for]} = open
    assert {reason.type, urgent.type, for.type} == {:string, :boolean, :user}

    assert Interaction.command_name(interaction) == "ticket"
    assert Interaction.command_type(interaction) == :slash
    assert Interaction.sub_command_name(interaction) == "open"
    assert Interaction.get_option(interaction, "urgent", :unset) == false
    assert Interaction.get_option(interaction, "missing", :unset) == :unset

    assert Interaction.get_options(interaction) == %{
             "reason" => "bug",
             "urgent" => false,
             "for" => "42"
           }

    assert %EDA.Member{nick: "Annie", user: %EDA.User{username: "ann"}} =
             Interaction.resolved(interaction, :members, "42")

    assert %EDA.Channel{name: "general"} = Interaction.resolved_channel(interaction, "7")
    assert Interaction.app_permissions(interaction, "7") == 2048
    assert Interaction.can?(interaction, "7", :send_messages)
  end

  test "the helpers read a raw interaction map the same way" do
    assert Interaction.get_options(@command) == Interaction.get_options(event(@command))
    assert %EDA.User{username: "ann"} = Interaction.resolved(@command, "users", "42")
  end

  test "autocomplete data is command data, the focused option marked" do
    interaction =
      event(%{
        "type" => 4,
        "data" => %{
          "name" => "tag",
          "type" => 1,
          "options" => [%{"name" => "q", "type" => 3, "value" => "he", "focused" => true}]
        }
      })

    assert %CommandData{options: [%Option{focused: true, value: "he"}]} = interaction.data
  end

  test "a select's data: its custom id, kind, values and resolved users" do
    interaction =
      event(%{
        "type" => 3,
        "data" => %{
          "custom_id" => "who",
          "component_type" => 5,
          "values" => ["42"],
          "resolved" => %{"users" => %{"42" => %{"id" => "42", "username" => "ann"}}}
        }
      })

    assert %ComponentData{custom_id: "who", component_type: :user_select, values: ["42"]} =
             interaction.data

    assert Interaction.custom_id(interaction) == "who"
    assert Interaction.component_type(interaction) == :user_select
    assert Interaction.selected_values(interaction) == ["42"]
    assert %EDA.User{username: "ann"} = Interaction.resolved(interaction, :users, "42")
  end

  # A submission in both forms Discord sends: inputs in labels, and a text input in an action row.
  @modal %{
    "type" => 5,
    "data" => %{
      "custom_id" => "report",
      "components" => [
        %{
          "type" => 18,
          "id" => 1,
          "component" => %{"type" => 4, "id" => 2, "custom_id" => "subject", "value" => "Crash"}
        },
        %{
          "type" => 18,
          "id" => 3,
          "component" => %{"type" => 3, "id" => 4, "custom_id" => "platform", "values" => []}
        },
        %{
          "type" => 18,
          "id" => 5,
          "component" => %{"type" => 19, "id" => 6, "custom_id" => "shots", "values" => ["99"]}
        },
        %{
          "type" => 18,
          "id" => 7,
          "component" => %{"type" => 23, "custom_id" => "agree", "value" => true}
        },
        %{
          "type" => 18,
          "id" => 8,
          "component" => %{"type" => 21, "custom_id" => "size", "value" => nil}
        },
        %{"type" => 10, "id" => 9, "content" => "Thanks"},
        %{
          "type" => 1,
          "components" => [%{"type" => 4, "custom_id" => "details", "value" => "It broke"}]
        }
      ],
      "resolved" => %{"attachments" => %{"99" => %{"id" => "99", "filename" => "shot.png"}}}
    }
  }

  test "a modal submission's data is its components as structs" do
    interaction = event(@modal)

    assert %ModalSubmitData{custom_id: "report", components: [subject | _]} = interaction.data

    assert %EDA.Component.Label{
             component: %EDA.Component.TextInput{custom_id: "subject", value: "Crash"}
           } = subject

    assert Interaction.custom_id(interaction) == "report"
  end

  test "EDA.Modal reads the values and files out of it, event or raw map" do
    expected = %{
      "subject" => "Crash",
      "platform" => [],
      "shots" => ["99"],
      "agree" => true,
      "size" => nil,
      "details" => "It broke"
    }

    assert EDA.Modal.get_values(event(@modal)) == expected
    assert EDA.Modal.get_values(@modal) == expected
    assert [%EDA.Attachment{filename: "shot.png"}] = EDA.Modal.get_attachments(@modal, "shots")
  end
end
