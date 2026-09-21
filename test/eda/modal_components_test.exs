defmodule EDA.ModalComponentsTest do
  @moduledoc """
  Labels and the components that go in them: text fields, selects, file uploads, radio groups,
  checkbox groups and checkboxes.

  Component types, limits and submission shapes follow Discord's component reference. The type
  numbers are easy to get wrong — there is no 20 — so they are asserted, not assumed.
  """

  use ExUnit.Case, async: true

  import EDA.Modal

  import EDA.Component,
    only: [string_select: 3, select_option: 2, user_select: 2, text_display: 1]

  describe "label/3" do
    test "wraps a component, with an optional description" do
      l = label("Your name", text_field("name", :short), description: "As on your ID")

      assert l == %{
               type: 18,
               label: "Your name",
               description: "As on your ID",
               component: %{type: 4, custom_id: "name", style: 1}
             }
    end

    test "the label is at most 45 characters and the description 100" do
      assert_raise ArgumentError, ~r/label must be 1–45/, fn ->
        label(String.duplicate("a", 46), text_field("x", :short))
      end

      assert_raise ArgumentError, ~r/description must be at most 100/, fn ->
        label("ok", text_field("x", :short), description: String.duplicate("a", 101))
      end
    end

    test "refuses a text input carrying its own label" do
      # Discord deprecates the text input's label inside a Label; two labels would be ambiguous.
      assert_raise ArgumentError, ~r/text_field\/3 instead of text_input\/4/, fn ->
        label("Name", text_input("name", "Name", :short))
      end
    end

    test "refuses a disabled component — Discord errors on one in a modal" do
      assert_raise ArgumentError, ~r/disabled/, fn ->
        label("Pick", user_select("u", disabled: true))
      end
    end

    test "refuses what cannot go in a label, naming it" do
      assert_raise ArgumentError, ~r/cannot contain a text display/, fn ->
        label("Nope", text_display("hi"))
      end

      assert_raise ArgumentError, ~r/cannot contain a button/, fn ->
        label("Nope", EDA.Component.button("b", custom_id: "b"))
      end
    end

    test "accepts every select type" do
      for select <- [
            string_select("s", [select_option("A", "a")], []),
            user_select("u", []),
            EDA.Component.role_select("r", []),
            EDA.Component.mentionable_select("m", []),
            EDA.Component.channel_select("c", [])
          ] do
        assert %{type: 18, component: ^select} = label("Pick", select)
      end
    end
  end

  describe "text_field/3" do
    test "has no label of its own, and takes the text input options" do
      field =
        text_field("bio", :paragraph,
          placeholder: "hint",
          min_length: 10,
          max_length: 500,
          required: false,
          value: "prefilled"
        )

      assert field == %{
               type: 4,
               custom_id: "bio",
               style: 2,
               placeholder: "hint",
               min_length: 10,
               max_length: 500,
               required: false,
               value: "prefilled"
             }
    end

    test "rejects an unknown style" do
      assert_raise ArgumentError, ~r/style/, fn -> text_field("x", :long) end
    end
  end

  describe "file_upload/2" do
    test "type 19, with its range and file type filters" do
      upload = file_upload("shots", min_values: 1, max_values: 5, file_types: [:image, ".pdf"])

      assert upload.type == 19
      assert upload.custom_id == "shots"
      assert upload.min_values == 1
      assert upload.max_values == 5
      assert upload.file_types == ["image", ".pdf"]
    end

    test "file type filters go through EDA.FileType" do
      assert_raise ArgumentError, ~r/pdf/, fn -> file_upload("f", file_types: ["pdf"]) end
    end

    test "at most 10 files" do
      assert_raise ArgumentError, ~r/max_values must be 1–10/, fn ->
        file_upload("f", max_values: 11)
      end
    end

    test "min_values: 0 needs required: false, as Discord requires" do
      assert_raise ArgumentError, ~r/required: false/, fn -> file_upload("f", min_values: 0) end
      assert %{min_values: 0, required: false} = file_upload("f", min_values: 0, required: false)
    end

    test "min_values cannot exceed max_values" do
      assert_raise ArgumentError, ~r/cannot exceed/, fn ->
        file_upload("f", min_values: 4, max_values: 2)
      end
    end
  end

  describe "choice/3" do
    test "a label, a value, and optionally a description and a default" do
      assert choice("Warrior", "warrior", description: "Strong", default: true) ==
               %{label: "Warrior", value: "warrior", description: "Strong", default: true}
    end

    test "each is at most 100 characters" do
      assert_raise ArgumentError, ~r/choice label/, fn ->
        choice(String.duplicate("a", 101), "v")
      end
    end
  end

  describe "radio_group/3" do
    test "type 21, between 2 and 10 options" do
      group = radio_group("class", [choice("A", "a"), choice("B", "b")], required: false)

      assert group.type == 21
      assert group.required == false
      assert length(group.options) == 2

      assert_raise ArgumentError, ~r/2–10 options/, fn -> radio_group("c", [choice("A", "a")]) end

      assert_raise ArgumentError, ~r/2–10 options/, fn ->
        radio_group("c", for(i <- 1..11, do: choice("#{i}", "#{i}")))
      end
    end

    test "at most one option starts selected" do
      assert_raise ArgumentError, ~r/at most one default/, fn ->
        radio_group("c", [choice("A", "a", default: true), choice("B", "b", default: true)])
      end
    end

    test "option values are unique" do
      assert_raise ArgumentError, ~r/unique/, fn ->
        radio_group("c", [choice("A", "same"), choice("B", "same")])
      end
    end
  end

  describe "checkbox_group/3" do
    test "type 22, between 1 and 10 options, with a selection range" do
      group = checkbox_group("days", [choice("Mon", "mon"), choice("Fri", "fri")], max_values: 2)

      assert group.type == 22
      assert group.max_values == 2

      assert_raise ArgumentError, ~r/1–10 options/, fn -> checkbox_group("d", []) end
    end

    test "min_values: 0 needs required: false" do
      assert_raise ArgumentError, ~r/required: false/, fn ->
        checkbox_group("d", [choice("A", "a")], min_values: 0)
      end
    end
  end

  describe "checkbox/2" do
    test "type 23, optionally ticked" do
      assert checkbox("subscribe", default: true) ==
               %{type: 23, custom_id: "subscribe", default: true}
    end

    test "cannot be required, and says what to use instead" do
      assert_raise ArgumentError, ~r/checkbox_group with one option/, fn ->
        checkbox("agree", required: true)
      end
    end
  end

  describe "modal/3 with a list" do
    test "labels and text displays are top-level; bare text inputs keep their action row" do
      m =
        modal("form", "Form", [
          text_display("Read this first"),
          label("Name", text_field("name", :short)),
          text_input("legacy", "Legacy", :short)
        ])

      assert [%{type: 10}, %{type: 18}, %{type: 1, components: [%{type: 4}]}] = m.components
    end

    test "a component that needs a label is refused bare, naming the fix" do
      assert_raise ArgumentError, ~r/radio group must be wrapped in label\/3/, fn ->
        modal("form", "Form", [radio_group("r", [choice("A", "a"), choice("B", "b")])])
      end
    end

    test "1 to 5 components" do
      assert_raise ArgumentError, ~r/at least 1/, fn -> modal("form", "Form", []) end

      six = for i <- 1..6, do: label("F#{i}", text_field("f#{i}", :short))
      assert_raise ArgumentError, ~r/at most 5/, fn -> modal("form", "Form", six) end
    end

    test "encodes to the payload Discord documents" do
      m =
        modal("bug_modal", "Bug Report", [
          label(
            "What's your favorite bug?",
            string_select("bug", [select_option("Ant", "ant")], [])
          ),
          label("Why?", text_field("why", :paragraph, required: true),
            description: "Please provide as much detail as possible!"
          )
        ])

      assert %{
               "custom_id" => "bug_modal",
               "components" => [
                 %{"type" => 18, "component" => %{"type" => 3, "custom_id" => "bug"}},
                 %{
                   "type" => 18,
                   "description" => "Please provide as much detail as possible!",
                   "component" => %{"type" => 4, "style" => 2, "required" => true}
                 }
               ]
             } = m |> Jason.encode!() |> Jason.decode!()
    end
  end

  describe "select options for modals" do
    test "required, on every select type" do
      assert %{required: false} = string_select("s", [select_option("A", "a")], required: false)
      assert %{required: true} = user_select("u", required: true)
      assert %{required: false} = EDA.Component.channel_select("c", required: false)
    end

    test "default values, typed by the select" do
      assert %{default_values: [%{id: "1", type: "user"}]} =
               user_select("u", default_values: ["1"])

      assert %{default_values: [%{id: "2", type: "role"}]} =
               EDA.Component.role_select("r", default_values: [2])

      assert %{default_values: [%{id: "3", type: "channel"}]} =
               EDA.Component.channel_select("c", default_values: ["3"])

      assert %{default_values: [%{id: "4", type: "user"}, %{id: "5", type: "role"}]} =
               EDA.Component.mentionable_select("m",
                 max_values: 2,
                 default_values: [{:user, "4"}, {:role, "5"}]
               )
    end

    test "a mentionable default must say whether it is a user or a role" do
      assert_raise ArgumentError, ~r/\{:user, id\} or \{:role, id\}/, fn ->
        EDA.Component.mentionable_select("m", default_values: ["4"])
      end
    end

    test "no more defaults than max_values, which Discord defaults to 1" do
      assert_raise ArgumentError, ~r/exceed max_values \(1\)/, fn ->
        user_select("u", default_values: ["1", "2"])
      end
    end
  end

  describe "get_values/1 on a label-based submission" do
    test "each value has the shape of its component" do
      values = get_values(submission())

      assert values == %{
               "name" => "Ada",
               "platform" => ["windows", "linux"],
               "reviewer" => ["111"],
               "evidence" => ["900", "901"],
               "severity" => "high",
               "days" => ["mon"],
               "subscribe" => true
             }
    end

    test "an optional radio group left empty is nil, an empty checkbox group is []" do
      interaction =
        submission_with([
          label_submission(%{"type" => 21, "custom_id" => "r", "value" => nil}),
          label_submission(%{"type" => 22, "custom_id" => "g", "values" => []})
        ])

      assert get_values(interaction) == %{"r" => nil, "g" => []}
    end

    test "text displays carry no value" do
      interaction =
        submission_with([
          %{"type" => 10, "id" => 1},
          label_submission(%{"type" => 4, "custom_id" => "t", "value" => "x"})
        ])

      assert get_values(interaction) == %{"t" => "x"}
    end

    test "atom-keyed interaction data is read too" do
      %{"data" => data} = submission()
      assert get_value(%{data: data}, "severity") == "high"
    end

    test "the earlier action-row submissions still work" do
      interaction =
        submission_with([
          %{"type" => 1, "components" => [%{"type" => 4, "custom_id" => "a", "value" => "1"}]}
        ])

      assert get_values(interaction) == %{"a" => "1"}
    end
  end

  describe "get_attachments/2" do
    test "returns the uploaded files as structs, in upload order" do
      [first, second] = get_attachments(submission(), "evidence")

      assert %EDA.Attachment{id: "900", filename: "bug.png"} = first
      assert %EDA.Attachment{id: "901", filename: "log.txt"} = second
    end

    test "is empty for a missing or non-upload component" do
      assert get_attachments(submission(), "nope") == []
      assert get_attachments(submission(), "severity") == []
    end
  end

  # ── Fixtures — the shapes of Discord's documented submission examples ──

  defp label_submission(component), do: %{"type" => 18, "id" => 1, "component" => component}

  defp submission_with(components) do
    %{"type" => 5, "data" => %{"custom_id" => "form", "components" => components}}
  end

  defp submission do
    interaction =
      submission_with([
        label_submission(%{"type" => 4, "custom_id" => "name", "value" => "Ada"}),
        label_submission(%{
          "type" => 3,
          "custom_id" => "platform",
          "values" => ["windows", "linux"]
        }),
        label_submission(%{"type" => 5, "custom_id" => "reviewer", "values" => ["111"]}),
        label_submission(%{"type" => 19, "custom_id" => "evidence", "values" => ["900", "901"]}),
        label_submission(%{"type" => 21, "custom_id" => "severity", "value" => "high"}),
        label_submission(%{"type" => 22, "custom_id" => "days", "values" => ["mon"]}),
        label_submission(%{"type" => 23, "custom_id" => "subscribe", "value" => true})
      ])

    put_in(interaction, ["data", "resolved"], %{
      "attachments" => %{
        "900" => %{
          "id" => "900",
          "filename" => "bug.png",
          "content_type" => "image/png",
          "size" => 241_394,
          "url" => "https://cdn.discordapp.com/ephemeral-attachments/1/900/bug.png",
          "ephemeral" => true
        },
        "901" => %{"id" => "901", "filename" => "log.txt", "size" => 12}
      }
    })
  end
end
