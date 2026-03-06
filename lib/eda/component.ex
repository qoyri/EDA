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
    * `:disabled` - If `true`, select is greyed out

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
    put_if(map, :disabled, opts[:disabled])
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
    * `:disabled` - If `true`, select is greyed out

  ## Example

      user_select("pick_user", placeholder: "Choose a user")
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
    * Plus all common select options (`:placeholder`, `:min_values`, `:max_values`, `:disabled`)

  ## Example

      channel_select("pick_channel", channel_types: [:guild_text], placeholder: "Choose a channel")
  """
  @spec channel_select(String.t(), keyword()) :: map()
  def channel_select(custom_id, opts \\ []) when is_binary(custom_id) do
    validate_custom_id!(custom_id)

    channel_type_map = %{
      guild_text: 0,
      dm: 1,
      guild_voice: 2,
      group_dm: 3,
      guild_category: 4,
      guild_announcement: 5,
      announcement_thread: 10,
      public_thread: 11,
      private_thread: 12,
      guild_stage_voice: 13,
      guild_forum: 15,
      guild_media: 16
    }

    map = %{type: @channel_select, custom_id: custom_id}
    map = put_if(map, :placeholder, opts[:placeholder])
    map = put_if(map, :min_values, opts[:min_values])
    map = put_if(map, :max_values, opts[:max_values])
    map = put_if(map, :disabled, opts[:disabled])

    case opts[:channel_types] do
      nil ->
        map

      types when is_list(types) ->
        resolved =
          Enum.map(types, fn t ->
            channel_type_map[t] ||
              raise ArgumentError, "unknown channel type #{inspect(t)}"
          end)

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
    put_if(map, :disabled, opts[:disabled])
  end

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

  defp put_if(map, _key, nil), do: map
  defp put_if(map, _key, false), do: map
  defp put_if(map, key, value), do: Map.put(map, key, value)
end
