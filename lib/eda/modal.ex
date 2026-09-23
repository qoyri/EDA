defmodule EDA.Modal do
  @moduledoc """
  Builder for Discord Modal dialogs.

  Modals are popup forms shown as an interaction response (type 9). A modal holds 1–5 top-level
  components, a title, and a custom_id.

  ## Building a modal

  Each field sits in a `label/3`, which carries the field's label and an optional description.
  Inside a label goes one interactive component:

    * `text_field/3` — free-form text, single line or paragraph
    * `EDA.Component.string_select/3`, `user_select/2`, `role_select/2`, `mentionable_select/2`,
      `channel_select/2` — the select menus messages use, with `required: false` to make them
      optional
    * `file_upload/2` — 0 to 10 files
    * `radio_group/3` — exactly one choice among 2–10
    * `checkbox_group/3` — any number of choices among 1–10
    * `checkbox/2` — a single yes/no

  `EDA.Component.text_display/1` can also sit at the top level, for instructions between fields.

      import EDA.Modal
      import EDA.Component, only: [text_display: 1, user_select: 2]

      modal("report", "Report a member", [
        text_display("Reports go to the moderators only."),
        label("Who?", user_select("target", max_values: 1)),
        label("What happened?", text_field("details", :paragraph, max_length: 1000),
          description: "Links to messages help."
        ),
        label("Evidence", file_upload("evidence", max_values: 5, file_types: [:image])),
        label("Severity", radio_group("severity", [choice("Low", "low"), choice("High", "high")]))
      ])
      |> then(&EDA.Interaction.respond_modal(interaction, &1))

  Discord's limits are checked when the modal is built — lengths, option counts, where a
  component may be placed — so a mistake raises `ArgumentError` naming it, rather than coming
  back as an opaque `50035` when the modal is shown.

  ## The earlier form

  `text_input/4` builds a text input carrying its own label, which `modal/3..7` wraps in an
  action row. Discord still accepts that form but no longer recommends it, and it cannot hold any
  of the other components. It keeps working unchanged.

  ## Handling submissions

  `get_values/1` returns every submitted value by custom_id, in the shape of its component: a
  string for a text field, a list of strings for a select, a checkbox group or a file upload,
  a string or `nil` for a radio group, a boolean for a checkbox. `get_attachments/2` returns the
  files a file upload received.

      def handle_event({:INTERACTION_CREATE, interaction}) do
        if EDA.Interaction.interaction_type(interaction) == :modal_submit and
             EDA.Interaction.custom_id(interaction) == "report" do
          %{"target" => [user_id], "details" => details, "severity" => severity} =
            EDA.Modal.get_values(interaction)

          files = EDA.Modal.get_attachments(interaction, "evidence")
          # ...
        end
      end
  """

  alias EDA.Component

  @select_kinds [:string_select, :user_select, :role_select, :mentionable_select, :channel_select]
  @label_children [:text_input, :file_upload, :radio_group, :checkbox_group, :checkbox] ++
                    @select_kinds

  # ── Label ─────────────────────────────────────────────────────────

  @doc """
  Wraps a modal component with a label and an optional description (type 18).

  Every interactive component in a modal sits in a label. The label text is at most 45
  characters, the description at most 100; Discord shows the description above or below the
  component depending on the platform.

  A text input built with `text_input/4` carries a label of its own, which Discord deprecates
  inside a label; use `text_field/3` here instead.

  ## Options

    * `:description` — hint text for the field (max 100 chars)
    * `:id` — optional numeric identifier for the component

  ## Example

      label("Your name", text_field("name", :short))
      label("Favourite colour", string_select("colour", options), description: "Pick one")
  """
  @spec label(String.t(), Component.t(), keyword()) :: Component.Label.t()
  def label(text, component, opts \\ []) when is_binary(text) and is_map(component) do
    validate_label!(text)
    validate_label_child!(component)

    %Component.Label{label: text, component: component}
    |> put_if(:description, validate_max(opts[:description], 100, "label description"))
    |> put_if(:id, opts[:id])
  end

  # ── Text inputs ───────────────────────────────────────────────────

  @doc """
  Creates a text input for use inside `label/3` (type 4).

  The label and description belong to the `label/3` around it.

  ## Options

    * `:placeholder` — hint text when empty (max 100 chars)
    * `:min_length` — minimum input length (0–4000)
    * `:max_length` — maximum input length (1–4000)
    * `:required` — whether the field must be filled (Discord defaults to `true`)
    * `:value` — pre-filled text (max 4000 chars)

  ## Example

      label("About you", text_field("bio", :paragraph, max_length: 1000, required: false))
  """
  @spec text_field(String.t(), :short | :paragraph, keyword()) :: Component.TextInput.t()
  def text_field(custom_id, style, opts \\ []) when is_binary(custom_id) do
    validate_custom_id!(custom_id)
    build_text_input(%Component.TextInput{custom_id: custom_id}, style, opts)
  end

  @doc """
  Creates a text input carrying its own label, for the action-row form of `modal/3..7`.

  Discord no longer recommends this form; `label/3` around `text_field/3` replaces it and can
  also hold the other modal components.

  ## Parameters

    * `custom_id` — unique identifier for this field (1–100 chars)
    * `label` — label displayed above the input (max 45 chars)
    * `style` — `:short` (single line) or `:paragraph` (multi-line)

  ## Options

  Those of `text_field/3`.

  ## Example

      text_input("name", "Your Name", :short, placeholder: "John Doe")
      text_input("bio", "About You", :paragraph, required: false, max_length: 1000)
  """
  @spec text_input(String.t(), String.t(), :short | :paragraph, keyword()) ::
          Component.TextInput.t()
  def text_input(custom_id, label, style, opts \\ [])
      when is_binary(custom_id) and is_binary(label) do
    validate_custom_id!(custom_id)
    validate_label!(label)

    build_text_input(%Component.TextInput{custom_id: custom_id, label: label}, style, opts)
  end

  # ── File upload ───────────────────────────────────────────────────

  @doc """
  Creates a file upload for use inside `label/3` (type 19).

  The user can attach 0 to 10 files; each is limited by the user's own upload limit in the
  channel. The submitted files arrive as attachments — see `get_attachments/2`.

  ## Options

    * `:min_values` — minimum number of files (0–10, Discord defaults to 1)
    * `:max_values` — maximum number of files (1–10, Discord defaults to 1)
    * `:required` — whether a file must be attached to submit (Discord defaults to `true`)
    * `:file_types` — up to 10 filters: `:image`, `:video`, `:audio`, or a dot-prefixed extension
      such as `".pdf"`. See `EDA.FileType`: the filter matches the extension only and never
      inspects the file, so it does not replace checking what was actually uploaded.

  `:min_values` of 0 needs `required: false`; Discord refuses the combination otherwise.

  ## Example

      label("Screenshots", file_upload("shots", max_values: 5, file_types: [:image]))
  """
  @spec file_upload(String.t(), keyword()) :: Component.FileUpload.t()
  def file_upload(custom_id, opts \\ []) when is_binary(custom_id) do
    validate_custom_id!(custom_id)

    %Component.FileUpload{custom_id: custom_id}
    |> put_values_range(opts, 0..10, 1..10)
    |> put_required(opts)
    |> put_if(:file_types, file_types(opts[:file_types]))
    |> check_min_against_required(opts)
  end

  # ── Choices ───────────────────────────────────────────────────────

  @doc """
  Creates an option for `radio_group/3` or `checkbox_group/3`.

  ## Options

    * `:description` — shown under the label (max 100 chars)
    * `:default` — whether the option starts selected

  ## Example

      choice("Warrior", "warrior", description: "Strong and brave")
  """
  @spec choice(String.t(), String.t(), keyword()) :: Component.SelectOption.t()
  def choice(label, value, opts \\ []) when is_binary(label) and is_binary(value) do
    validate_max(label, 100, "choice label")
    validate_max(value, 100, "choice value")

    %Component.SelectOption{label: label, value: value}
    |> put_if(:description, validate_max(opts[:description], 100, "choice description"))
    |> put_if(:default, validate_boolean(opts[:default], :default))
  end

  @doc """
  Creates a radio group for use inside `label/3` (type 21): exactly one choice among 2–10.

  At most one option may start selected. The submitted value is the chosen option's value, or
  `nil` when the group is optional and left empty.

  ## Options

    * `:required` — whether a choice is needed to submit (Discord defaults to `true`)

  ## Example

      label("Class", radio_group("class", [choice("Warrior", "warrior"), choice("Rogue", "rogue")]))
  """
  @spec radio_group(String.t(), [Component.SelectOption.t()], keyword()) ::
          Component.RadioGroup.t()
  def radio_group(custom_id, options, opts \\ [])
      when is_binary(custom_id) and is_list(options) do
    validate_custom_id!(custom_id)
    validate_choices!(options, 2..10, "radio_group")

    if Enum.count(options, &(&1[:default] == true)) > 1 do
      raise ArgumentError, "radio_group allows at most one default option"
    end

    put_required(%Component.RadioGroup{custom_id: custom_id, options: options}, opts)
  end

  @doc """
  Creates a checkbox group for use inside `label/3` (type 22): any number of choices among
  1–10.

  The submitted value is the list of chosen values, empty when none is ticked.

  ## Options

    * `:min_values` — minimum choices (0–10, Discord defaults to 1)
    * `:max_values` — maximum choices (1–10, Discord defaults to the number of options)
    * `:required` — whether a choice is needed to submit (Discord defaults to `true`)

  `:min_values` of 0 needs `required: false`.

  ## Example

      label("Free days", checkbox_group("days", [choice("Monday", "mon"), choice("Friday", "fri")]))
  """
  @spec checkbox_group(String.t(), [Component.SelectOption.t()], keyword()) ::
          Component.CheckboxGroup.t()
  def checkbox_group(custom_id, options, opts \\ [])
      when is_binary(custom_id) and is_list(options) do
    validate_custom_id!(custom_id)
    validate_choices!(options, 1..10, "checkbox_group")

    %Component.CheckboxGroup{custom_id: custom_id, options: options}
    |> put_values_range(opts, 0..10, 1..10)
    |> put_required(opts)
    |> check_min_against_required(opts)
  end

  @doc """
  Creates a single checkbox for use inside `label/3` (type 23).

  The submitted value is `true` or `false`. A checkbox cannot be required; for a box that must
  be ticked, use a `checkbox_group/3` with one option.

  ## Options

    * `:default` — whether it starts ticked

  ## Example

      label("Subscribe to updates", checkbox("subscribe", default: true))
  """
  @spec checkbox(String.t(), keyword()) :: Component.Checkbox.t()
  def checkbox(custom_id, opts \\ []) when is_binary(custom_id) do
    validate_custom_id!(custom_id)

    if Keyword.has_key?(opts, :required) do
      raise ArgumentError,
            "a checkbox cannot be required; use a checkbox_group with one option instead"
    end

    put_if(
      %Component.Checkbox{custom_id: custom_id},
      :default,
      validate_boolean(opts[:default], :default)
    )
  end

  # ── Modal Builder ─────────────────────────────────────────────────

  @doc """
  Creates a modal from its top-level components.

  `components` is a list of 1–5 `label/3` and `EDA.Component.text_display/1` components. Text
  inputs from `text_input/4` are also accepted, each wrapped in an action row as before.

  The older positional form, `modal(custom_id, title, input1, ..., input5)`, still works.

  ## Example

      modal("survey", "Quick Survey", [
        label("Favourite colour?", text_field("q1", :short)),
        label("Why?", text_field("q2", :paragraph, required: false))
      ])
  """
  @spec modal(
          String.t(),
          String.t(),
          [map()] | map(),
          map() | nil,
          map() | nil,
          map() | nil,
          map() | nil
        ) ::
          map()
  def modal(custom_id, title, input1, input2 \\ nil, input3 \\ nil, input4 \\ nil, input5 \\ nil)

  def modal(custom_id, title, components, nil, nil, nil, nil) when is_list(components) do
    build_modal(custom_id, title, components)
  end

  def modal(custom_id, title, input1, input2, input3, input4, input5) when is_map(input1) do
    inputs =
      [input1, input2, input3, input4, input5]
      |> Enum.reject(&is_nil/1)

    build_modal(custom_id, title, inputs)
  end

  @doc """
  Creates a modal from a list of components. Same as `modal/3` with a list.

      modal_from_list("profile", "Edit Profile", [
        label("Name", text_field("name", :short)),
        label("Bio", text_field("bio", :paragraph))
      ])
  """
  @spec modal_from_list(String.t(), String.t(), [map()]) :: map()
  def modal_from_list(custom_id, title, inputs) when is_list(inputs) do
    build_modal(custom_id, title, inputs)
  end

  # ── Submission Helpers ────────────────────────────────────────────

  @doc """
  Extracts all submitted values from a MODAL_SUBMIT interaction, by custom_id.

  Each value has the shape of its component:

    * text field — the text, a string
    * select, checkbox group — the chosen values, a list of strings (ids for user, role,
      mentionable and channel selects)
    * file upload — the attachment ids, a list of strings; `get_attachments/2` returns the files
    * radio group — the chosen value, or `nil`
    * checkbox — `true` or `false`

  ## Example

      EDA.Modal.get_values(interaction)
      # => %{"subject" => "Bug report", "platform" => ["windows"], "agree" => true}
  """
  @spec get_values(map()) :: %{String.t() => term()}
  def get_values(interaction) do
    case EDA.Interaction.data(interaction) do
      %EDA.Interaction.ModalSubmitData{components: components} when is_list(components) ->
        extract_values(components)

      _ ->
        %{}
    end
  end

  @doc """
  Extracts a single value from a MODAL_SUBMIT interaction by custom_id.

  Returns `default` (`nil` unless given) when the modal has no such component. See
  `get_values/1` for the shape of each value.

  ## Example

      subject = EDA.Modal.get_value(interaction, "subject")
  """
  @spec get_value(map(), String.t(), term()) :: term()
  def get_value(interaction, custom_id, default \\ nil) do
    Map.get(get_values(interaction), custom_id, default)
  end

  @doc """
  Returns the files a `file_upload/2` received, as `EDA.Attachment` structs, in upload order.

  Returns `[]` when the component is absent or nothing was uploaded.

  ## Example

      for file <- EDA.Modal.get_attachments(interaction, "evidence") do
        {file.filename, file.url}
      end
  """
  @spec get_attachments(map(), String.t()) :: [EDA.Attachment.t()]
  def get_attachments(interaction, custom_id) do
    case get_value(interaction, custom_id) do
      ids when is_list(ids) ->
        for id <- ids, file = EDA.Interaction.resolved(interaction, :attachments, id), do: file

      _ ->
        []
    end
  end

  defp extract_values(components) do
    components
    |> Enum.flat_map(&interactive_children/1)
    |> Map.new(&{&1.custom_id, submitted_value(&1)})
  end

  # A submission nests each input in a label (`component`) or, in the earlier form, an action row
  # (`components`). Text displays carry no value; a kind EDA does not know is left out.
  defp interactive_children(%EDA.Component.Label{component: child}),
    do: interactive_children(child)

  defp interactive_children(%EDA.Component.ActionRow{components: children}),
    do: Enum.flat_map(children || [], &interactive_children/1)

  defp interactive_children(%{custom_id: id} = child) when is_binary(id), do: [child]
  defp interactive_children(_), do: []

  # Several choices come back as a list, empty when none was made; one choice as its value.
  defp submitted_value(%{values: values}) when is_list(values), do: values
  defp submitted_value(%{values: nil}), do: []
  defp submitted_value(%{value: value}), do: value
  defp submitted_value(_), do: nil

  # ── Private ───────────────────────────────────────────────────────

  defp build_modal(custom_id, title, components) do
    validate_custom_id!(custom_id)
    validate_title!(title)

    if components == [] do
      raise ArgumentError, "modal must have at least 1 component"
    end

    if length(components) > 5 do
      raise ArgumentError, "modal can have at most 5 components, got: #{length(components)}"
    end

    %{
      custom_id: custom_id,
      title: title,
      components: Enum.map(components, &top_level/1)
    }
  end

  # A bare text input is the earlier form and goes in an action row; labels and text displays
  # are top-level as they are. Anything else would be refused by Discord.
  defp top_level(component) do
    case Component.kind(component) do
      :text_input ->
        %Component.ActionRow{components: [component]}

      kind when kind in [:label, :text_display, :action_row] ->
        component

      kind when kind in @label_children ->
        raise ArgumentError, "a #{name(kind)} must be wrapped in label/3 to be placed in a modal"

      nil ->
        raise ArgumentError, "not a component: #{inspect(component)}"

      kind ->
        raise ArgumentError, "a #{name(kind)} cannot be placed in a modal"
    end
  end

  defp validate_label_child!(component) do
    case Component.kind(component) do
      kind when kind in @label_children ->
        if component[:disabled] do
          raise ArgumentError, "a modal cannot contain a disabled component"
        end

        if kind == :text_input and component[:label] != nil do
          raise ArgumentError,
                "a text input inside a label takes no label of its own; " <>
                  "build it with text_field/3 instead of text_input/4"
        end

        :ok

      nil ->
        raise ArgumentError, "not a component: #{inspect(component)}"

      kind ->
        raise ArgumentError, "a label cannot contain a #{name(kind)}"
    end
  end

  defp name(kind) when is_atom(kind), do: kind |> Atom.to_string() |> String.replace("_", " ")
  defp name(kind), do: "component of type #{kind}"

  defp build_text_input(input, style, opts) do
    if style not in [:short, :paragraph] do
      raise ArgumentError, "style must be :short or :paragraph, got: #{inspect(style)}"
    end

    input
    |> Map.put(:style, style)
    |> put_if(:placeholder, validate_max(opts[:placeholder], 100, "placeholder"))
    |> put_if(:min_length, validate_length_bound(opts[:min_length], :min_length))
    |> put_if(:max_length, validate_length_bound(opts[:max_length], :max_length))
    |> put_if(:value, validate_max(opts[:value], 4000, "value"))
    |> put_required(opts)
  end

  defp put_values_range(map, opts, min_range, max_range) do
    map
    |> put_if(:min_values, validate_in(opts[:min_values], min_range, :min_values))
    |> put_if(:max_values, validate_in(opts[:max_values], max_range, :max_values))
    |> tap(fn m ->
      if m[:min_values] && m[:max_values] && m.min_values > m.max_values do
        raise ArgumentError,
              "min_values (#{m.min_values}) cannot exceed max_values (#{m.max_values})"
      end
    end)
  end

  defp put_required(map, opts),
    do: put_if(map, :required, validate_boolean(opts[:required], :required))

  # Discord: min_values must be omitted or at least 1 unless the component is optional.
  defp check_min_against_required(map, opts) do
    if map[:min_values] == 0 and opts[:required] != false do
      raise ArgumentError, "min_values: 0 needs required: false"
    end

    map
  end

  defp file_types(nil), do: nil
  defp file_types(filters), do: EDA.FileType.normalize!(filters)

  defp validate_choices!(options, range, where) do
    unless length(options) in range do
      raise ArgumentError,
            "#{where} requires #{range.first}–#{range.last} options, got: #{length(options)}"
    end

    values = Enum.map(options, & &1[:value])

    if Enum.uniq(values) != values do
      raise ArgumentError, "#{where} option values must be unique"
    end
  end

  defp validate_custom_id!(id) do
    if byte_size(id) == 0 or String.length(id) > 100 do
      raise ArgumentError, "custom_id must be 1–100 characters, got: #{String.length(id)}"
    end
  end

  defp validate_label!(label) do
    if byte_size(label) == 0 or String.length(label) > 45 do
      raise ArgumentError, "label must be 1–45 characters, got: #{String.length(label)}"
    end
  end

  defp validate_title!(title) do
    if byte_size(title) == 0 or String.length(title) > 45 do
      raise ArgumentError, "title must be 1–45 characters, got: #{String.length(title)}"
    end
  end

  defp validate_max(nil, _max, _what), do: nil

  defp validate_max(text, max, what) when is_binary(text) do
    if String.length(text) > max do
      raise ArgumentError,
            "#{what} must be at most #{max} characters, got: #{String.length(text)}"
    end

    text
  end

  defp validate_length_bound(nil, _), do: nil

  defp validate_length_bound(n, field) when is_integer(n) do
    if n < 0 or n > 4000 do
      raise ArgumentError, "#{field} must be 0–4000, got: #{n}"
    end

    n
  end

  defp validate_in(nil, _range, _field), do: nil

  defp validate_in(n, range, field) when is_integer(n) do
    unless n in range do
      raise ArgumentError, "#{field} must be #{range.first}–#{range.last}, got: #{n}"
    end

    n
  end

  defp validate_in(other, _range, field),
    do: raise(ArgumentError, "#{field} must be an integer, got: #{inspect(other)}")

  defp validate_boolean(nil, _field), do: nil
  defp validate_boolean(value, _field) when is_boolean(value), do: value

  defp validate_boolean(other, field),
    do: raise(ArgumentError, "#{field} must be boolean, got: #{inspect(other)}")

  defp put_if(map, _key, nil), do: map
  defp put_if(map, key, value), do: Map.put(map, key, value)
end
