defmodule EDA.Component do
  @moduledoc """
  Builder for Discord Components V2.

  All builders return plain maps ready for JSON encoding — no structs needed.
  Components V2 messages require the `IS_COMPONENTS_V2` flag (`1 << 15 = 32768`).

  ## Example

      import EDA.Component

      msg =
        container(
          accent_color: 0x5865F2,
          components: [
            text_display("# Welcome!"),
            separator(spacing: :large),
            section(
              text_display("Check out this cool feature"),
              accessory: thumbnail("https://example.com/thumb.png")
            ),
            action_row([
              button("Click me", custom_id: "btn_1", style: :primary),
              link_button("Visit", "https://example.com")
            ])
          ]
        )

      EDA.API.Message.create(channel_id, components: [msg], v2: true)

  ## Received components

  The components of a received message are structs, one per kind: `EDA.Component.ActionRow`,
  `Button`, `SelectMenu` (with its `SelectOption`s), `Section`, `TextDisplay`, `Thumbnail`,
  `MediaGallery`, `File`, `Separator` and `Container`, their images an `EDA.Component.Media`.
  A submitted modal adds `Label`, `TextInput`, `FileUpload`, `RadioGroup`, `CheckboxGroup` and
  `Checkbox`, each with the `value` or `values` the user gave.
  Each has its `type` as an atom, Discord's name lowercased (`:action_row`, `:string_select`…),
  and the `id` Discord numbers it with. A kind EDA does not know yet stays the raw map.

  They can be sent back as they are, mixed with maps from the builders, which is how a message
  is edited in place:

      components = EDA.Component.disable_all(message.components)
      EDA.Message.edit(message, components: components)
  """

  # ── Component Type Constants ───────────────────────────────────────

  @action_row 1
  @button 2
  @string_select 3
  @user_select 5
  @role_select 6
  @mentionable_select 7
  @channel_select 8
  @section 9
  @text_display 10
  @thumbnail 11
  @media_gallery 12
  # @file is reserved in Elixir, so we use the literal value inline
  # File component type = 13
  @separator 14
  @container 17

  @type_names %{
    1 => :action_row,
    2 => :button,
    3 => :string_select,
    4 => :text_input,
    5 => :user_select,
    6 => :role_select,
    7 => :mentionable_select,
    8 => :channel_select,
    9 => :section,
    10 => :text_display,
    11 => :thumbnail,
    12 => :media_gallery,
    13 => :file,
    14 => :separator,
    17 => :container,
    18 => :label,
    19 => :file_upload,
    21 => :radio_group,
    22 => :checkbox_group,
    23 => :checkbox
  }

  @structs %{
    1 => EDA.Component.ActionRow,
    2 => EDA.Component.Button,
    3 => EDA.Component.SelectMenu,
    5 => EDA.Component.SelectMenu,
    6 => EDA.Component.SelectMenu,
    7 => EDA.Component.SelectMenu,
    8 => EDA.Component.SelectMenu,
    9 => EDA.Component.Section,
    10 => EDA.Component.TextDisplay,
    11 => EDA.Component.Thumbnail,
    12 => EDA.Component.MediaGallery,
    13 => EDA.Component.File,
    14 => EDA.Component.Separator,
    17 => EDA.Component.Container,
    4 => EDA.Component.TextInput,
    18 => EDA.Component.Label,
    19 => EDA.Component.FileUpload,
    21 => EDA.Component.RadioGroup,
    22 => EDA.Component.CheckboxGroup,
    23 => EDA.Component.Checkbox
  }

  @typedoc "A component's kind, Discord's name lowercased; a kind added later stays its integer."
  @type type ::
          :action_row
          | :button
          | :string_select
          | :text_input
          | :user_select
          | :role_select
          | :mentionable_select
          | :channel_select
          | :section
          | :text_display
          | :thumbnail
          | :media_gallery
          | :file
          | :separator
          | :container
          | :label
          | :file_upload
          | :radio_group
          | :checkbox_group
          | :checkbox
          | integer()

  @type button_style :: :primary | :secondary | :success | :danger | :link | :premium

  @typedoc "A received component, or the raw map of a kind EDA does not know yet."
  @type t ::
          EDA.Component.ActionRow.t()
          | EDA.Component.Button.t()
          | EDA.Component.SelectMenu.t()
          | EDA.Component.Section.t()
          | EDA.Component.TextDisplay.t()
          | EDA.Component.Thumbnail.t()
          | EDA.Component.MediaGallery.t()
          | EDA.Component.File.t()
          | EDA.Component.Separator.t()
          | EDA.Component.Container.t()
          | EDA.Component.TextInput.t()
          | EDA.Component.Label.t()
          | EDA.Component.FileUpload.t()
          | EDA.Component.RadioGroup.t()
          | EDA.Component.CheckboxGroup.t()
          | EDA.Component.Checkbox.t()
          | map()

  # ── Button Styles ──────────────────────────────────────────────────

  @button_styles %{
    primary: 1,
    secondary: 2,
    success: 3,
    danger: 4,
    link: 5,
    premium: 6
  }

  # ── Separator Spacing ──────────────────────────────────────────────

  @separator_spacing %{
    small: 1,
    large: 2
  }

  @separator_spacing_names Map.new(@separator_spacing, fn {k, v} -> {v, k} end)
  @button_style_names Map.new(@button_styles, fn {k, v} -> {v, k} end)

  # ── Reading ────────────────────────────────────────────────────────

  @doc """
  A component as Discord sends it, as its struct; a kind EDA does not know stays the raw map.

      iex> EDA.Component.from_raw(%{"type" => 2, "style" => 1, "label" => "Go", "custom_id" => "go"})
      %EDA.Component.Button{style: :primary, label: "Go", custom_id: "go", disabled: false}
      iex> EDA.Component.from_raw(%{"type" => 99, "content" => "?"})
      %{"type" => 99, "content" => "?"}
  """
  @spec from_raw(map()) :: t()
  def from_raw(%{"type" => type} = raw) when is_map_key(@structs, type),
    do: Map.fetch!(@structs, type).from_raw(raw)

  def from_raw(raw) when is_map(raw), do: raw

  @doc false
  def parse(nil), do: nil
  def parse(raw), do: from_raw(raw)

  @doc false
  def parse_list(nil), do: nil
  def parse_list(list) when is_list(list), do: Enum.map(list, &from_raw/1)

  @doc false
  def parse_emoji(nil), do: nil
  def parse_emoji(raw), do: EDA.Emoji.from_raw(raw)

  @doc false
  def parse_options(nil), do: nil
  def parse_options(list), do: Enum.map(list, &EDA.Component.SelectOption.from_raw/1)

  @text_input_styles %{1 => :short, 2 => :paragraph}

  @doc false
  def text_input_style(style), do: EDA.Enum.name(@text_input_styles, style)

  @doc false
  def type_name(type), do: EDA.Enum.name(@type_names, type)

  @doc false
  def button_style(style), do: EDA.Enum.name(@button_style_names, style)

  @doc false
  def spacing(spacing), do: EDA.Enum.name(@separator_spacing_names, spacing)

  @doc """
  A component struct as the map Discord takes, down to its children; maps pass through.

  The component structs encode to JSON this way, so they can be sent as they are.

      iex> EDA.Component.to_raw(%EDA.Component.Separator{id: 3, divider: true, spacing: :large})
      %{type: 14, id: 3, divider: true, spacing: 2}
  """
  @spec to_raw(struct() | map()) :: map()
  def to_raw(%_{} = component) do
    component
    |> Map.from_struct()
    |> Enum.reduce(%{}, fn {key, value}, acc ->
      case encode_field(component, key, value) do
        nil -> acc
        encoded -> Map.put(acc, key, encoded)
      end
    end)
  end

  def to_raw(map) when is_map(map), do: map

  defp encode_field(_component, _key, nil), do: nil

  defp encode_field(_component, :type, type) when is_atom(type),
    do: EDA.Enum.value!(@type_names, type, "component type")

  defp encode_field(%EDA.Component.TextInput{}, :style, style) when is_atom(style),
    do: EDA.Enum.value!(@text_input_styles, style, "text input style")

  defp encode_field(_component, :style, style) when is_atom(style),
    do: EDA.Enum.value!(@button_style_names, style, "button style")

  defp encode_field(_component, key, value), do: encode_field(key, value)

  defp encode_field(:spacing, spacing) when is_atom(spacing),
    do: EDA.Enum.value!(@separator_spacing_names, spacing, "separator spacing")

  defp encode_field(:channel_types, types), do: Enum.map(types, &EDA.Channel.type_value/1)

  defp encode_field(:default_values, values) do
    Enum.map(values, fn
      {type, id} -> %{id: to_string(id), type: to_string(type)}
      map -> map
    end)
  end

  defp encode_field(:emoji, %EDA.Emoji{} = emoji) do
    %{id: emoji.id, name: emoji.name, animated: emoji.animated}
    |> Map.reject(fn {_k, v} -> is_nil(v) end)
  end

  defp encode_field(key, %EDA.Component.Media{url: url}) when key in [:media, :file],
    do: %{url: url}

  defp encode_field(key, list) when key in [:components, :items, :options] and is_list(list),
    do: Enum.map(list, &to_raw/1)

  defp encode_field(key, %_{} = child) when key in [:accessory, :component], do: to_raw(child)
  defp encode_field(_key, value), do: value

  # ── Layout Components ──────────────────────────────────────────────

  @doc """
  Creates a container component (type 17) — the top-level V2 wrapper.

  ## Options

    * `:components` - List of child components (max 10, required)
    * `:accent_color` - Integer color value for the left border
    * `:spoiler` - If `true`, content is hidden behind a spoiler

  ## Example

      container(
        accent_color: 0xFF0000,
        components: [
          text_display("Hello!"),
          separator(),
          text_display("World!")
        ]
      )
  """
  @spec container(keyword()) :: map()
  def container(opts) when is_list(opts) do
    components = opts[:components] || raise ArgumentError, "container requires :components"

    if not is_list(components) or components == [] do
      raise ArgumentError, "container :components must be a non-empty list"
    end

    if length(components) > 10 do
      raise ArgumentError, "container cannot have more than 10 components"
    end

    map = %{type: @container, components: components}
    map = put_if(map, :accent_color, opts[:accent_color])
    put_if(map, :spoiler, opts[:spoiler])
  end

  @doc """
  Creates an action row component (type 1).

  Holds up to 5 buttons, or exactly 1 select menu.

  ## Example

      action_row([
        button("Yes", custom_id: "confirm", style: :success),
        button("No", custom_id: "cancel", style: :danger)
      ])
  """
  @spec action_row(list()) :: map()
  def action_row(components) when is_list(components) do
    if components == [] do
      raise ArgumentError, "action_row requires at least one component"
    end

    select_types = [
      @string_select,
      @user_select,
      @role_select,
      @mentionable_select,
      @channel_select
    ]

    has_select = Enum.any?(components, fn c -> c[:type] in select_types end)
    has_button = Enum.any?(components, fn c -> c[:type] == @button end)

    cond do
      has_select and has_button ->
        raise ArgumentError, "action_row cannot mix select menus and buttons"

      has_select and length(components) > 1 ->
        raise ArgumentError, "action_row can only contain one select menu"

      has_button and length(components) > 5 ->
        raise ArgumentError, "action_row cannot have more than 5 buttons"

      true ->
        :ok
    end

    %{type: @action_row, components: components}
  end

  @doc """
  Creates a section component (type 9).

  A section contains 1–3 text displays and an optional accessory (thumbnail or button).

  ## Examples

      section(text_display("Some text"), accessory: thumbnail("https://example.com/img.png"))

      section([
        text_display("Line 1"),
        text_display("Line 2")
      ], accessory: button("Click", custom_id: "btn"))
  """
  @spec section(map() | [map()], keyword()) :: map()
  def section(text, opts \\ [])

  def section(%{type: @text_display} = single, opts) do
    section([single], opts)
  end

  def section(texts, opts) when is_list(texts) do
    if texts == [] or length(texts) > 3 do
      raise ArgumentError, "section requires 1–3 text_display components"
    end

    unless Enum.all?(texts, fn c -> c[:type] == @text_display end) do
      raise ArgumentError, "section components must all be text_display"
    end

    map = %{type: @section, components: texts}

    case opts[:accessory] do
      nil ->
        raise ArgumentError,
              "section requires an :accessory (thumbnail or button). " <>
                "Example: section([text], accessory: thumbnail(\"url\"))"

      %{type: type} = accessory when type in [@thumbnail, @button] ->
        Map.put(map, :accessory, accessory)

      _ ->
        raise ArgumentError, "section accessory must be a thumbnail or button"
    end
  end

  @doc """
  Creates a separator component (type 14).

  ## Options

    * `:divider` - Whether to show a visible line (default `true`)
    * `:spacing` - `:small` (1) or `:large` (2)

  ## Example

      separator()
      separator(spacing: :large)
      separator(divider: false, spacing: :small)
  """
  @spec separator(keyword()) :: map()
  def separator(opts \\ []) do
    map = %{type: @separator}

    map =
      case opts[:divider] do
        nil -> map
        val when is_boolean(val) -> Map.put(map, :divider, val)
        _ -> raise ArgumentError, "separator :divider must be a boolean"
      end

    case opts[:spacing] do
      nil ->
        map

      spacing when spacing in [:small, :large] ->
        Map.put(map, :spacing, @separator_spacing[spacing])

      _ ->
        raise ArgumentError, "separator :spacing must be :small or :large"
    end
  end

  # ── Content Components ─────────────────────────────────────────────

  @doc """
  Creates a text display component (type 10).

  Supports full markdown.

  ## Example

      text_display("# Hello World")
      text_display("**Bold** and *italic*")
  """
  @spec text_display(String.t()) :: map()
  def text_display(content) when is_binary(content) do
    if content == "" do
      raise ArgumentError, "text_display content cannot be empty"
    end

    %{type: @text_display, content: content}
  end

  @doc """
  Creates a thumbnail component (type 11).

  ## Options

    * `:description` - Alt text / description
    * `:spoiler` - If `true`, image is hidden behind a spoiler

  ## Example

      thumbnail("https://example.com/img.png")
      thumbnail("https://example.com/img.png", description: "A nice image", spoiler: true)
  """
  @spec thumbnail(String.t(), keyword()) :: map()
  def thumbnail(url, opts \\ []) when is_binary(url) do
    if url == "" do
      raise ArgumentError, "thumbnail url cannot be empty"
    end

    map = %{type: @thumbnail, media: %{url: url}}
    map = put_if(map, :description, opts[:description])
    put_if(map, :spoiler, opts[:spoiler])
  end

  @doc """
  Creates a media gallery component (type 12).

  Takes a list of 1–10 media items built with `media_item/2`.

  ## Example

      media_gallery([
        media_item("https://example.com/img1.png", description: "First"),
        media_item("https://example.com/img2.png")
      ])
  """
  @spec media_gallery([map()]) :: map()
  def media_gallery(items) when is_list(items) do
    if items == [] or length(items) > 10 do
      raise ArgumentError, "media_gallery requires 1–10 items"
    end

    %{type: @media_gallery, items: items}
  end

  @doc """
  Creates a media item for use in `media_gallery/1`.

  ## Options

    * `:description` - Caption for the media item
    * `:spoiler` - If `true`, item is hidden behind a spoiler

  ## Example

      media_item("https://example.com/image.png", description: "My image")
  """
  @spec media_item(String.t(), keyword()) :: map()
  def media_item(url, opts \\ []) when is_binary(url) do
    if url == "" do
      raise ArgumentError, "media_item url cannot be empty"
    end

    map = %{media: %{url: url}}
    map = put_if(map, :description, opts[:description])
    put_if(map, :spoiler, opts[:spoiler])
  end

  @doc """
  Creates a file component (type 13).

  The URL must use the `attachment://` scheme.

  ## Options

    * `:spoiler` - If `true`, file is hidden behind a spoiler

  ## Example

      file("attachment://report.pdf")
  """
  @spec file(String.t(), keyword()) :: map()
  def file(url, opts \\ []) when is_binary(url) do
    unless String.starts_with?(url, "attachment://") do
      raise ArgumentError, "file url must use the attachment:// scheme"
    end

    map = %{type: 13, file: %{url: url}}
    put_if(map, :spoiler, opts[:spoiler])
  end

  # ── Interactive Components ─────────────────────────────────────────

  @doc """
  Creates a button component (type 2).

  ## Options

    * `:style` - Button style atom: `:primary`, `:secondary`, `:success`, `:danger`, `:link`, `:premium`
    * `:custom_id` - Unique ID for non-link buttons (max 100 chars)
    * `:url` - URL for link-style buttons
    * `:emoji` - Emoji map `%{name: "👍"}` or `%{id: "12345", name: "custom"}`
    * `:disabled` - If `true`, button is greyed out
    * `:sku_id` - SKU ID for premium buttons

  ## Example

      button("Click me", custom_id: "my_btn", style: :primary)
      button("Visit", url: "https://example.com", style: :link)
  """
  @spec button(String.t(), keyword()) :: map()
  def button(label, opts \\ []) when is_binary(label) do
    if String.length(label) > 80 do
      raise ArgumentError, "button label must be at most 80 characters"
    end

    style_atom = opts[:style] || :secondary

    style =
      @button_styles[style_atom] ||
        raise ArgumentError,
              "unknown button style #{inspect(style_atom)}, expected one of: #{inspect(Map.keys(@button_styles))}"

    %{type: @button, style: style, label: label}
    |> put_button_identifier(style_atom, opts)
    |> put_if(:emoji, opts[:emoji])
    |> put_if(:disabled, opts[:disabled])
  end

  @doc """
  Convenience for creating a link-style button.

  ## Example

      link_button("Visit", "https://example.com")
      link_button("Docs", "https://docs.example.com", emoji: %{name: "📚"})
  """
  @spec link_button(String.t(), String.t(), keyword()) :: map()
  def link_button(label, url, opts \\ []) do
    button(label, Keyword.merge(opts, style: :link, url: url))
  end

  @doc """
  Creates a string select menu component (type 3).

  ## Options

    * `:placeholder` - Placeholder text shown when nothing is selected
    * `:min_values` - Minimum selections required (default 1)
    * `:max_values` - Maximum selections allowed (default 1)
    * `:disabled` - If `true`, select is greyed out. Messages only: a modal refuses it
    * `:required` - In a modal, whether a choice is needed to submit (Discord defaults to
      `true`). Ignored in messages

  ## Example

      string_select("color_select", [
        select_option("Red", "red"),
        select_option("Blue", "blue", description: "A cool color"),
        select_option("Green", "green", emoji: %{name: "🟢"})
      ], placeholder: "Pick a color")
  """
  @spec string_select(String.t(), [map()], keyword()) :: map()
  def string_select(custom_id, options, opts \\ [])
      when is_binary(custom_id) and is_list(options) do
    validate_custom_id!(custom_id)

    if options == [] or length(options) > 25 do
      raise ArgumentError, "string_select requires 1–25 options"
    end

    map = %{type: @string_select, custom_id: custom_id, options: options}
    map = put_if(map, :placeholder, opts[:placeholder])
    map = put_if(map, :min_values, opts[:min_values])
    map = put_if(map, :max_values, opts[:max_values])
    map = put_if(map, :disabled, opts[:disabled])
    put_required(map, opts)
  end

  @doc """
  Creates an option for `string_select/3`.

  ## Options

    * `:description` - Description shown under the option label (max 100 chars)
    * `:emoji` - Emoji map
    * `:default` - If `true`, this option is pre-selected

  ## Example

      select_option("Red", "red", description: "The color red", emoji: %{name: "🔴"})
  """
  @spec select_option(String.t(), String.t(), keyword()) :: map()
  def select_option(label, value, opts \\ []) when is_binary(label) and is_binary(value) do
    if String.length(label) > 100 do
      raise ArgumentError, "select_option label must be at most 100 characters"
    end

    if String.length(value) > 100 do
      raise ArgumentError, "select_option value must be at most 100 characters"
    end

    desc = opts[:description]

    if desc && String.length(desc) > 100 do
      raise ArgumentError, "select_option description must be at most 100 characters"
    end

    map = %{label: label, value: value}
    map = put_if(map, :description, desc)
    map = put_if(map, :emoji, opts[:emoji])
    put_if(map, :default, opts[:default])
  end

  @doc """
  Creates a user select menu component (type 5).

  ## Options

    * `:placeholder` - Placeholder text
    * `:min_values` / `:max_values` - Selection range
    * `:disabled` - If `true`, select is greyed out. Messages only: a modal refuses it
    * `:required` - In a modal, whether a choice is needed to submit (Discord defaults to
      `true`). Ignored in messages
    * `:default_values` - Users selected up front, as a list of ids. No more than
      `:max_values`, which Discord defaults to 1

  The same options apply to `role_select/2`, `mentionable_select/2` and `channel_select/2`.
  A mentionable select mixes users and roles, so its defaults are `{:user, id}` or
  `{:role, id}` tuples.

  ## Example

      user_select("pick_user", placeholder: "Choose a user")
      user_select("reviewers", max_values: 3, default_values: [author_id])
  """
  @spec user_select(String.t(), keyword()) :: map()
  def user_select(custom_id, opts \\ []) when is_binary(custom_id) do
    build_auto_select(@user_select, custom_id, opts)
  end

  @doc """
  Creates a role select menu component (type 6).

  ## Example

      role_select("pick_role", placeholder: "Choose a role")
  """
  @spec role_select(String.t(), keyword()) :: map()
  def role_select(custom_id, opts \\ []) when is_binary(custom_id) do
    build_auto_select(@role_select, custom_id, opts)
  end

  @doc """
  Creates a mentionable select menu component (type 7).

  ## Example

      mentionable_select("pick_mention", placeholder: "Choose user or role")
  """
  @spec mentionable_select(String.t(), keyword()) :: map()
  def mentionable_select(custom_id, opts \\ []) when is_binary(custom_id) do
    build_auto_select(@mentionable_select, custom_id, opts)
  end

  @doc """
  Creates a channel select menu component (type 8).

  ## Options

    * `:channel_types` - List of channel type atoms to filter
    * Plus the options of `user_select/2`, with channel ids as `:default_values`

  ## Example

      channel_select("pick_channel", channel_types: [:guild_text], placeholder: "Choose a channel")
  """
  @spec channel_select(String.t(), keyword()) :: map()
  def channel_select(custom_id, opts \\ []) when is_binary(custom_id) do
    validate_custom_id!(custom_id)

    map = %{type: @channel_select, custom_id: custom_id}
    map = put_if(map, :placeholder, opts[:placeholder])
    map = put_if(map, :min_values, opts[:min_values])
    map = put_if(map, :max_values, opts[:max_values])
    map = put_if(map, :disabled, opts[:disabled])
    map = put_required(map, opts)
    map = put_default_values(map, @channel_select, opts)

    case opts[:channel_types] do
      nil ->
        map

      types when is_list(types) ->
        resolved =
          Enum.map(types, &EDA.Channel.type_value/1)

        Map.put(map, :channel_types, resolved)
    end
  end

  # ── Private Helpers ────────────────────────────────────────────────

  defp build_auto_select(type, custom_id, opts) do
    validate_custom_id!(custom_id)

    map = %{type: type, custom_id: custom_id}
    map = put_if(map, :placeholder, opts[:placeholder])
    map = put_if(map, :min_values, opts[:min_values])
    map = put_if(map, :max_values, opts[:max_values])
    map = put_if(map, :disabled, opts[:disabled])
    map = put_required(map, opts)
    put_default_values(map, type, opts)
  end

  defp put_required(map, opts) do
    case opts[:required] do
      nil -> map
      value when is_boolean(value) -> Map.put(map, :required, value)
      other -> raise ArgumentError, "required must be boolean, got: #{inspect(other)}"
    end
  end

  @default_value_types %{
    @user_select => "user",
    @role_select => "role",
    @channel_select => "channel"
  }

  # Discord takes default values as `%{id, type}` objects, and refuses more of them than
  # max_values allows — which it defaults to 1.
  defp put_default_values(map, select_type, opts) do
    case opts[:default_values] do
      nil ->
        map

      values when is_list(values) ->
        max = opts[:max_values] || 1

        if length(values) > max do
          raise ArgumentError,
                "#{length(values)} default_values exceed max_values (#{max}); " <>
                  "raise :max_values to preselect more"
        end

        Map.put(map, :default_values, Enum.map(values, &default_value(select_type, &1)))

      other ->
        raise ArgumentError, "default_values must be a list, got: #{inspect(other)}"
    end
  end

  defp default_value(@mentionable_select, {type, id}) when type in [:user, :role],
    do: %{id: to_string(id), type: Atom.to_string(type)}

  defp default_value(@mentionable_select, other) do
    raise ArgumentError,
          "a mentionable select mixes users and roles, so each default value must be " <>
            "{:user, id} or {:role, id}, got: #{inspect(other)}"
  end

  defp default_value(select_type, id) when is_binary(id) or is_integer(id),
    do: %{id: to_string(id), type: Map.fetch!(@default_value_types, select_type)}

  defp default_value(_select_type, other),
    do: raise(ArgumentError, "a default value must be an id, got: #{inspect(other)}")

  defp put_button_identifier(map, :link, opts) do
    url = opts[:url] || raise ArgumentError, "link button requires :url"
    Map.put(map, :url, url)
  end

  defp put_button_identifier(map, :premium, opts) do
    sku_id = opts[:sku_id] || raise ArgumentError, "premium button requires :sku_id"
    Map.put(map, :sku_id, sku_id)
  end

  defp put_button_identifier(map, _style, opts) do
    custom_id = opts[:custom_id] || raise ArgumentError, "non-link button requires :custom_id"

    if String.length(custom_id) > 100 do
      raise ArgumentError, "button custom_id must be at most 100 characters"
    end

    Map.put(map, :custom_id, custom_id)
  end

  defp validate_custom_id!(custom_id) do
    if String.length(custom_id) > 100 do
      raise ArgumentError, "custom_id must be at most 100 characters"
    end
  end

  # ── Bulk Operations ─────────────────────────────────────────────────

  # Interactive component types: button (2), string_select (3),
  # user_select (5), role_select (6), mentionable_select (7), channel_select (8)
  @interactive_types [2, 3, 5, 6, 7, 8]

  @doc """
  Recursively disables all interactive components (buttons, select menus)
  in a component tree.

  Useful after a user interacts with a message — disable all buttons/selects
  to prevent further clicks, then update the message.

  Non-interactive components (text, thumbnails, separators, etc.) are left untouched.

  ## Examples

      disabled = EDA.Component.disable_all(message.components)

      EDA.Interaction.respond(interaction,
        type: :update,
        components: disabled
      )
  """
  @spec disable_all([t()] | nil) :: [t()]
  def disable_all(nil), do: []

  def disable_all(components) when is_list(components) do
    Enum.map(components, &disable_component/1)
  end

  defp disable_component(%EDA.Component.Button{} = c), do: %{c | disabled: true}
  defp disable_component(%EDA.Component.SelectMenu{} = c), do: %{c | disabled: true}

  defp disable_component(%EDA.Component.Section{accessory: accessory} = c),
    do: %{c | accessory: disable_component(accessory)}

  defp disable_component(%{"type" => t} = c) when t in @interactive_types do
    Map.put(c, "disabled", true)
  end

  defp disable_component(%{type: t} = c) when t in @interactive_types do
    Map.put(c, :disabled, true)
  end

  defp disable_component(%{"accessory" => accessory} = c) when is_map(accessory),
    do: Map.put(c, "accessory", disable_component(accessory))

  defp disable_component(%{accessory: accessory} = c) when is_map(accessory),
    do: Map.put(c, :accessory, disable_component(accessory))

  defp disable_component(%{"components" => children} = c) do
    Map.put(c, "components", disable_all(children))
  end

  defp disable_component(%{components: children} = c) do
    %{c | components: disable_all(children)}
  end

  defp disable_component(c), do: c

  defp put_if(map, _key, nil), do: map
  defp put_if(map, _key, false), do: map
  defp put_if(map, key, value), do: Map.put(map, key, value)
end
