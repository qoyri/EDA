defmodule EDA.ModalTest do
  use ExUnit.Case, async: true

  import EDA.Modal

  # ── text_input/4 ──────────────────────────────────────────────────

  describe "text_input/4" do
    test "short style" do
      input = text_input("name", "Your Name", :short)
      assert input.type == :text_input
      assert input.custom_id == "name"
      assert input.label == "Your Name"
      assert input.style == :short
    end

    test "paragraph style" do
      input = text_input("bio", "About You", :paragraph)
      assert input.style == :paragraph
    end

    test "all options" do
      input =
        text_input("field", "Label", :short,
          placeholder: "hint",
          min_length: 5,
          max_length: 100,
          required: false,
          value: "default"
        )

      assert input.placeholder == "hint"
      assert input.min_length == 5
      assert input.max_length == 100
      assert input.required == false
      assert input.value == "default"
    end

    test "required defaults to omitted (Discord defaults to true)" do
      input = text_input("id", "Label", :short)
      assert input.required == nil
    end

    test "optional fields are omitted when nil" do
      input = text_input("id", "Label", :short)
      assert input.placeholder == nil
      assert input.min_length == nil
      assert input.max_length == nil
      assert input.value == nil
    end

    test "invalid style raises" do
      assert_raise ArgumentError, ~r/style must be/, fn ->
        text_input("id", "Label", :invalid)
      end
    end

    test "empty custom_id raises" do
      assert_raise ArgumentError, ~r/custom_id/, fn ->
        text_input("", "Label", :short)
      end
    end

    test "custom_id over 100 chars raises" do
      assert_raise ArgumentError, ~r/custom_id/, fn ->
        text_input(String.duplicate("a", 101), "Label", :short)
      end
    end

    test "label over 45 chars raises" do
      assert_raise ArgumentError, ~r/label/, fn ->
        text_input("id", String.duplicate("a", 46), :short)
      end
    end

    test "placeholder over 100 chars raises" do
      assert_raise ArgumentError, ~r/placeholder/, fn ->
        text_input("id", "Label", :short, placeholder: String.duplicate("a", 101))
      end
    end

    test "value over 4000 chars raises" do
      assert_raise ArgumentError, ~r/value/, fn ->
        text_input("id", "Label", :short, value: String.duplicate("a", 4001))
      end
    end

    test "min_length out of range raises" do
      assert_raise ArgumentError, ~r/min_length/, fn ->
        text_input("id", "Label", :short, min_length: -1)
      end
    end

    test "max_length out of range raises" do
      assert_raise ArgumentError, ~r/max_length/, fn ->
        text_input("id", "Label", :short, max_length: 4001)
      end
    end
  end

  # ── modal/3+ ──────────────────────────────────────────────────────

  describe "modal/3+" do
    test "creates a modal with one input" do
      m = modal("id", "Title", text_input("f1", "Field", :short))

      assert m.custom_id == "id"
      assert m.title == "Title"
      assert length(m.components) == 1

      [row] = m.components
      assert row.type == :action_row
      assert length(row.components) == 1
      assert hd(row.components).custom_id == "f1"
    end

    test "creates a modal with multiple inputs" do
      m =
        modal(
          "id",
          "Title",
          text_input("f1", "One", :short),
          text_input("f2", "Two", :paragraph)
        )

      assert length(m.components) == 2
    end

    test "up to 5 inputs" do
      m =
        modal(
          "id",
          "Title",
          text_input("f1", "A", :short),
          text_input("f2", "B", :short),
          text_input("f3", "C", :short),
          text_input("f4", "D", :short),
          text_input("f5", "E", :short)
        )

      assert length(m.components) == 5
    end

    test "empty title raises" do
      assert_raise ArgumentError, ~r/title/, fn ->
        modal("id", "", text_input("f1", "A", :short))
      end
    end

    test "title over 45 chars raises" do
      assert_raise ArgumentError, ~r/title/, fn ->
        modal("id", String.duplicate("a", 46), text_input("f1", "A", :short))
      end
    end

    test "JSON-encodable" do
      m =
        modal(
          "test",
          "Test Modal",
          text_input("name", "Name", :short, placeholder: "enter name"),
          text_input("desc", "Description", :paragraph, required: false)
        )

      assert {:ok, json} = Jason.encode(m)
      decoded = Jason.decode!(json)

      assert decoded["custom_id"] == "test"
      assert decoded["title"] == "Test Modal"
      assert length(decoded["components"]) == 2
    end
  end

  # ── modal_from_list/3 ────────────────────────────────────────────

  describe "modal_from_list/3" do
    test "works with a list of inputs" do
      inputs = [
        text_input("f1", "One", :short),
        text_input("f2", "Two", :paragraph)
      ]

      m = modal_from_list("id", "Title", inputs)
      assert length(m.components) == 2
    end

    test "empty list raises" do
      assert_raise ArgumentError, ~r/at least 1/, fn ->
        modal_from_list("id", "Title", [])
      end
    end

    test "more than 5 inputs raises" do
      inputs = for i <- 1..6, do: text_input("f#{i}", "F#{i}", :short)

      assert_raise ArgumentError, ~r/at most 5/, fn ->
        modal_from_list("id", "Title", inputs)
      end
    end
  end

  # ── Submission Helpers ────────────────────────────────────────────

  describe "get_values/1" do
    test "extracts all values from modal submit" do
      interaction = modal_submit_fixture()
      values = get_values(interaction)

      assert values == %{
               "subject" => "Bug report",
               "body" => "The bot crashed when I clicked the button"
             }
    end

    test "returns empty map for non-modal interaction" do
      assert get_values(%{}) == %{}
      assert get_values(%{"data" => %{}}) == %{}
    end
  end

  describe "get_value/3" do
    test "extracts a single value" do
      interaction = modal_submit_fixture()
      assert get_value(interaction, "subject") == "Bug report"
      assert get_value(interaction, "body") == "The bot crashed when I clicked the button"
    end

    test "returns nil for missing field" do
      interaction = modal_submit_fixture()
      assert get_value(interaction, "nonexistent") == nil
    end

    test "returns default for missing field" do
      interaction = modal_submit_fixture()
      assert get_value(interaction, "nonexistent", "fallback") == "fallback"
    end
  end

  # ── Fixtures ──────────────────────────────────────────────────────

  defp modal_submit_fixture do
    %{
      "id" => "111",
      "type" => 5,
      "token" => "tok",
      "application_id" => "222",
      "data" => %{
        "custom_id" => "feedback_form",
        "components" => [
          %{
            "type" => 1,
            "components" => [
              %{"type" => 4, "custom_id" => "subject", "value" => "Bug report"}
            ]
          },
          %{
            "type" => 1,
            "components" => [
              %{
                "type" => 4,
                "custom_id" => "body",
                "value" => "The bot crashed when I clicked the button"
              }
            ]
          }
        ]
      }
    }
  end
end
