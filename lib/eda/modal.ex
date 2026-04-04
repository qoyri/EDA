defmodule EDA.Modal do
  @moduledoc """
  Builder for Discord Modal dialogs.

  Modals are popup forms with text inputs, shown as an interaction response (type 9).
  Each modal contains 1–5 text inputs, a title, and a custom_id.

  ## Features

  - **Dedicated builder API** — no need to construct raw maps manually
  - **Validation** — enforces Discord limits at build time (title length, input count, etc.)
  - **`text_input/3`** builder with all options (min/max length, placeholder, value, required)
  - **`get_value/2`** helper to extract submitted values from MODAL_SUBMIT interactions

  ## Example

      import EDA.Modal

      modal =
        modal("feedback_form", "Send Feedback",
          text_input("subject", "Subject", :short,
            placeholder: "Brief summary",
            min_length: 1,
            max_length: 100
          ),
          text_input("body", "Details", :paragraph,
            placeholder: "Describe in detail...",
            required: false
          )
        )

      # Send as interaction response
      EDA.Interaction.respond_modal(interaction, modal)

  ## Handling submissions

      def handle_event({:INTERACTION_CREATE, interaction}) do
        import EDA.Interaction
        import EDA.Modal

        if interaction_type(interaction) == :modal_submit and custom_id(interaction) == "feedback_form" do
          subject = get_value(interaction, "subject")
          body = get_value(interaction, "body")
          respond(interaction, "Got it: \#{subject}")
        end
      end
  """

  @text_input_type 4
  @action_row_type 1

  @text_input_styles %{short: 1, paragraph: 2}

  # ── Text Input Builder ────────────────────────────────────────────

  @doc """
  Creates a text input component for use inside a modal.

  ## Parameters

    * `custom_id` — unique identifier for this field (1–100 chars)
    * `label` — label displayed above the input (max 45 chars)
    * `style` — `:short` (single line) or `:paragraph` (multi-line)

  ## Options

    * `:placeholder` — hint text when empty (max 100 chars)
    * `:min_length` — minimum input length (0–4000)
    * `:max_length` — maximum input length (1–4000)
    * `:required` — whether the field must be filled (default `true`)
    * `:value` — pre-filled text (max 4000 chars)

  ## Example

      text_input("name", "Your Name", :short, placeholder: "John Doe")
      text_input("bio", "About You", :paragraph, required: false, max_length: 1000)
  """
  @spec text_input(String.t(), String.t(), :short | :paragraph, keyword()) :: map()
  def text_input(custom_id, label, style, opts \\ [])
      when is_binary(custom_id) and is_binary(label) do
    validate_custom_id!(custom_id)
    validate_label!(label)

    style_val =
      Map.get(@text_input_styles, style) ||
        raise ArgumentError, "style must be :short or :paragraph, got: #{inspect(style)}"

    input = %{
      type: @text_input_type,
      custom_id: custom_id,
      label: label,
      style: style_val
    }

    input = put_if(input, :placeholder, validate_placeholder(opts[:placeholder]))
    input = put_if(input, :min_length, validate_length_bound(opts[:min_length], :min_length))
    input = put_if(input, :max_length, validate_length_bound(opts[:max_length], :max_length))
    input = put_if(input, :value, validate_value(opts[:value]))

    case opts[:required] do
      nil -> input
      val when is_boolean(val) -> Map.put(input, :required, val)
      other -> raise ArgumentError, "required must be boolean, got: #{inspect(other)}"
    end
  end

  # ── Modal Builder ─────────────────────────────────────────────────

  @doc """
  Creates a modal dialog with the given text inputs.

  ## Parameters

    * `custom_id` — unique identifier for the modal (1–100 chars)
    * `title` — title displayed at top (max 45 chars)
    * `inputs` — 1–5 text input maps (from `text_input/4`)

  ## Example

      modal("survey", "Quick Survey",
        text_input("q1", "Favorite color?", :short),
        text_input("q2", "Why?", :paragraph, required: false)
      )
  """
  @spec modal(String.t(), String.t(), map(), map(), map(), map(), map()) :: map()
  def modal(custom_id, title, input1, input2 \\ nil, input3 \\ nil, input4 \\ nil, input5 \\ nil) do
    inputs =
      [input1, input2, input3, input4, input5]
      |> Enum.reject(&is_nil/1)

    build_modal(custom_id, title, inputs)
  end

  @doc """
  Creates a modal dialog from a list of text inputs.

      inputs = [
        text_input("name", "Name", :short),
        text_input("bio", "Bio", :paragraph)
      ]
      modal_from_list("profile", "Edit Profile", inputs)
  """
  @spec modal_from_list(String.t(), String.t(), [map()]) :: map()
  def modal_from_list(custom_id, title, inputs) when is_list(inputs) do
    build_modal(custom_id, title, inputs)
  end

  # ── Submission Helpers ────────────────────────────────────────────

  @doc """
  Extracts all submitted values from a MODAL_SUBMIT interaction.

  Returns a map of `%{"custom_id" => "value"}`.

  ## Example

      values = EDA.Modal.get_values(interaction)
      # => %{"subject" => "Bug report", "body" => "The bot crashed..."}
  """
  @spec get_values(map()) :: %{String.t() => String.t()}
  def get_values(%{data: %{"components" => rows}}) when is_list(rows) do
    extract_values(rows)
  end

  def get_values(%{"data" => %{"components" => rows}}) when is_list(rows) do
    extract_values(rows)
  end

  def get_values(_), do: %{}

  defp extract_values(rows) do
    rows
    |> Enum.flat_map(fn
      %{"components" => components} when is_list(components) -> components
      _ -> []
    end)
    |> Map.new(fn
      %{"custom_id" => id, "value" => value} -> {id, value}
      %{"custom_id" => id} -> {id, nil}
    end)
  end

  @doc """
  Extracts a single value from a MODAL_SUBMIT interaction by custom_id.

  Returns `nil` if not found, or `default` if provided.

  ## Example

      subject = EDA.Modal.get_value(interaction, "subject")
  """
  @spec get_value(map(), String.t(), term()) :: String.t() | nil | term()
  def get_value(interaction, custom_id, default \\ nil) do
    Map.get(get_values(interaction), custom_id, default)
  end

  # ── Private ───────────────────────────────────────────────────────

  defp build_modal(custom_id, title, inputs) do
    validate_custom_id!(custom_id)
    validate_title!(title)

    if inputs == [] do
      raise ArgumentError, "modal must have at least 1 text input"
    end

    if length(inputs) > 5 do
      raise ArgumentError, "modal can have at most 5 text inputs, got: #{length(inputs)}"
    end

    components =
      Enum.map(inputs, fn input ->
        %{type: @action_row_type, components: [input]}
      end)

    %{
      custom_id: custom_id,
      title: title,
      components: components
    }
  end

  defp validate_custom_id!(id) do
    if byte_size(id) == 0 or byte_size(id) > 100 do
      raise ArgumentError, "custom_id must be 1–100 characters, got: #{byte_size(id)}"
    end
  end

  defp validate_label!(label) do
    if byte_size(label) == 0 or byte_size(label) > 45 do
      raise ArgumentError, "label must be 1–45 characters, got: #{byte_size(label)}"
    end
  end

  defp validate_title!(title) do
    if byte_size(title) == 0 or byte_size(title) > 45 do
      raise ArgumentError, "title must be 1–45 characters, got: #{byte_size(title)}"
    end
  end

  defp validate_placeholder(nil), do: nil

  defp validate_placeholder(p) when is_binary(p) do
    if byte_size(p) > 100 do
      raise ArgumentError, "placeholder must be at most 100 characters, got: #{byte_size(p)}"
    end

    p
  end

  defp validate_length_bound(nil, _), do: nil

  defp validate_length_bound(n, field) when is_integer(n) do
    if n < 0 or n > 4000 do
      raise ArgumentError, "#{field} must be 0–4000, got: #{n}"
    end

    n
  end

  defp validate_value(nil), do: nil

  defp validate_value(v) when is_binary(v) do
    if byte_size(v) > 4000 do
      raise ArgumentError, "value must be at most 4000 characters, got: #{byte_size(v)}"
    end

    v
  end

  defp put_if(map, _key, nil), do: map
  defp put_if(map, key, value), do: Map.put(map, key, value)
end
