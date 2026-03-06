defmodule EDA.Interaction do
  @moduledoc """
  Helpers for working with Discord interactions.

  Works directly with the raw interaction maps received from the gateway,
  providing convenient accessors and response helpers.

  ## Handling Slash Commands

      def handle_event({:INTERACTION_CREATE, interaction}) do
        import EDA.Interaction

        case command_name(interaction) do
          "ping" ->
            respond(interaction, "Pong!")

          "greet" ->
            msg = get_option(interaction, "message")
            target = get_option(interaction, "target")
            respond(interaction, content: "<@\#{target}> \#{msg}", ephemeral: true)

          "role" ->
            case sub_command_name(interaction) do
              "add" ->
                role_id = get_option(interaction, "role")
                respond(interaction, "Added <@&\#{role_id}>!")

              "remove" ->
                respond(interaction, "Removed!")
            end
        end
      end

  ## Deferred Responses

      # Show "thinking..." then edit later
      defer(interaction)
      # ... do work ...
      edit_response(interaction, content: "Done!")

      # Ephemeral defer
      defer(interaction, ephemeral: true)
  """

  @type interaction :: map()

  # ── Accessors ───────────────────────────────────────────────────────

  @doc "Returns the command name from the interaction data."
  @spec command_name(interaction()) :: String.t() | nil
  def command_name(%{data: %{"name" => name}}), do: name
  def command_name(%{"data" => %{"name" => name}}), do: name
  def command_name(_), do: nil

  @doc """
  Returns the command type as an atom.

  - `:slash` (type 1, CHAT_INPUT)
  - `:user` (type 2, USER context menu)
  - `:message` (type 3, MESSAGE context menu)
  """
  @spec command_type(interaction()) :: :slash | :user | :message | nil
  def command_type(%{data: %{"type" => 1}}), do: :slash
  def command_type(%{data: %{"type" => 2}}), do: :user
  def command_type(%{data: %{"type" => 3}}), do: :message
  def command_type(%{"data" => %{"type" => 1}}), do: :slash
  def command_type(%{"data" => %{"type" => 2}}), do: :user
  def command_type(%{"data" => %{"type" => 3}}), do: :message
  def command_type(_), do: nil

  @doc """
  Returns the interaction type as an atom.

  - `:ping` (1)
  - `:command` (2, APPLICATION_COMMAND)
  - `:component` (3, MESSAGE_COMPONENT)
  - `:autocomplete` (4, APPLICATION_COMMAND_AUTOCOMPLETE)
  - `:modal_submit` (5, MODAL_SUBMIT)
  """
  @spec interaction_type(interaction()) :: atom() | nil
  def interaction_type(%{type: 1}), do: :ping
  def interaction_type(%{type: 2}), do: :command
  def interaction_type(%{type: 3}), do: :component
  def interaction_type(%{type: 4}), do: :autocomplete
  def interaction_type(%{type: 5}), do: :modal_submit
  def interaction_type(%{"type" => 1}), do: :ping
  def interaction_type(%{"type" => 2}), do: :command
  def interaction_type(%{"type" => 3}), do: :component
  def interaction_type(%{"type" => 4}), do: :autocomplete
  def interaction_type(%{"type" => 5}), do: :modal_submit
  def interaction_type(_), do: nil

  @doc """
  Gets an option value by name from the interaction.

  Automatically traverses into sub_commands and sub_command_groups
  to find the option.

  Returns `nil` if not found, or `default` if provided.
  """
  @spec get_option(interaction(), String.t(), term()) :: term()
  def get_option(interaction, name, default \\ nil) do
    options = get_flat_options(interaction)

    case Enum.find(options, fn opt -> opt["name"] == name end) do
      %{"value" => value} -> value
      _ -> default
    end
  end

  @doc """
  Returns all options as a flat map of `%{"name" => value}`.

  Traverses sub_commands and sub_command_groups automatically.
  """
  @spec get_options(interaction()) :: %{String.t() => term()}
  def get_options(interaction) do
    interaction
    |> get_flat_options()
    |> Enum.filter(&Map.has_key?(&1, "value"))
    |> Map.new(fn opt -> {opt["name"], opt["value"]} end)
  end

  @doc """
  Returns the sub_command name, or `nil` if not a sub_command invocation.

  For sub_command_groups, returns `{group_name, sub_command_name}`.
  """
  @spec sub_command_name(interaction()) :: String.t() | {String.t(), String.t()} | nil
  def sub_command_name(%{
        data: %{
          "options" => [
            %{"type" => 2, "name" => group, "options" => [%{"type" => 1, "name" => sub} | _]} | _
          ]
        }
      }) do
    {group, sub}
  end

  def sub_command_name(%{data: %{"options" => [%{"type" => 1, "name" => name} | _]}}) do
    name
  end

  def sub_command_name(%{
        "data" => %{
          "options" => [
            %{"type" => 2, "name" => group, "options" => [%{"type" => 1, "name" => sub} | _]} | _
          ]
        }
      }) do
    {group, sub}
  end

  def sub_command_name(%{"data" => %{"options" => [%{"type" => 1, "name" => name} | _]}}) do
    name
  end

  def sub_command_name(_), do: nil

  @doc "Returns the user who triggered the interaction (works in both guild and DM)."
  @spec user(interaction()) :: EDA.User.t() | map() | nil
  def user(%{member: %EDA.Member{user: %EDA.User{} = user}}), do: user
  def user(%{member: %{"user" => user}}) when not is_nil(user), do: user
  def user(%{user: %EDA.User{} = user}), do: user
  def user(%{user: user}) when is_map(user), do: user
  def user(%{"member" => %{"user" => user}}) when not is_nil(user), do: user
  def user(%{"user" => user}) when not is_nil(user), do: user
  def user(_), do: nil

  @doc "Returns the guild member map, or `nil` in DMs."
  @spec member(interaction()) :: EDA.Member.t() | map() | nil
  def member(%{member: %EDA.Member{} = member}), do: member
  def member(%{member: member}) when is_map(member), do: member
  def member(%{"member" => member}), do: member
  def member(_), do: nil

  @doc "Returns the guild ID, or `nil` in DMs."
  @spec guild_id(interaction()) :: String.t() | nil
  def guild_id(%{guild_id: id}) when is_binary(id), do: id
  def guild_id(%{"guild_id" => id}), do: id
  def guild_id(_), do: nil

  @doc "Returns the channel ID."
  @spec channel_id(interaction()) :: String.t() | nil
  def channel_id(%{channel_id: id}) when is_binary(id), do: id
  def channel_id(%{"channel_id" => id}), do: id
  def channel_id(_), do: nil

  @doc "Returns the interaction token."
  @spec token(interaction()) :: String.t() | nil
  def token(%{token: token}) when is_binary(token), do: token
  def token(%{"token" => token}), do: token
  def token(_), do: nil

  @doc """
  Returns a resolved object by type and ID.

  Types: `"users"`, `"members"`, `"roles"`, `"channels"`, `"messages"`, `"attachments"`.
  """
  @spec resolved(interaction(), String.t(), String.t()) :: map() | nil
  def resolved(%{data: %{"resolved" => resolved}}, type, id) do
    get_in(resolved, [type, id])
  end

  def resolved(%{"data" => %{"resolved" => resolved}}, type, id) do
    get_in(resolved, [type, id])
  end

  def resolved(_, _, _), do: nil

  @doc """
  Returns the target ID for user/message context menu commands.
  """
  @spec target_id(interaction()) :: String.t() | nil
  def target_id(%{data: %{"target_id" => id}}), do: id
  def target_id(%{"data" => %{"target_id" => id}}), do: id
  def target_id(_), do: nil

  @doc "Returns the custom_id for component interactions and modal submits."
  @spec custom_id(interaction()) :: String.t() | nil
  def custom_id(%{data: %{"custom_id" => id}}), do: id
  def custom_id(%{"data" => %{"custom_id" => id}}), do: id
  def custom_id(_), do: nil

  @doc """
  Returns the selected values from a select menu interaction.

  Returns an empty list if the interaction is not a select menu.

  ## Examples

      values = EDA.Interaction.selected_values(interaction)
      # => ["option_1", "option_2"]
  """
  @spec selected_values(interaction()) :: [String.t()]
  def selected_values(%{data: %{"values" => values}}) when is_list(values), do: values
  def selected_values(%{"data" => %{"values" => values}}) when is_list(values), do: values
  def selected_values(_), do: []

  @doc """
  Returns the component type for a message component interaction.

  Returns `nil` if not a component interaction.

  Common types: `2` = button, `3` = string select, `5` = user select,
  `6` = role select, `7` = mentionable select, `8` = channel select.

  ## Examples

      case EDA.Interaction.component_type(interaction) do
        2 -> handle_button(interaction)
        3 -> handle_select(interaction)
        _ -> :ignore
      end
  """
  @spec component_type(interaction()) :: non_neg_integer() | nil
  def component_type(%{data: %{"component_type" => t}}), do: t
  def component_type(%{"data" => %{"component_type" => t}}), do: t
  def component_type(_), do: nil

  # ── Response Helpers ────────────────────────────────────────────────

  @doc """
  Sends an immediate response to the interaction.

  ## Examples

      respond(interaction, "Hello!")
      respond(interaction, content: "Hello!", ephemeral: true)
      respond(interaction, content: "Look!", embeds: [embed])
  """
  @spec respond(interaction(), String.t() | keyword()) :: :ok | {:error, term()}
  def respond(interaction, content) when is_binary(content) do
    respond(interaction, content: content)
  end

  def respond(interaction, opts) when is_list(opts) do
    {files, opts} = Keyword.pop(opts, :files, [])
    data = build_message_data(opts)
    payload = %{type: 4, data: data}

    EDA.API.Interaction.respond(
      interaction["id"],
      interaction["token"],
      payload,
      files
    )
  end

  @doc """
  Defers the interaction response (shows "thinking..." indicator).

  Must be followed by `edit_response/2` within 15 minutes.

  ## Options

    * `:ephemeral` - If `true`, the thinking indicator and subsequent
      response are only visible to the invoking user.
  """
  @spec defer(interaction(), keyword()) :: :ok | {:error, term()}
  def defer(interaction, opts \\ []) do
    data = if opts[:ephemeral], do: %{flags: 64}, else: %{}

    payload = %{type: 5, data: data}

    EDA.API.Interaction.respond(
      interaction["id"],
      interaction["token"],
      payload
    )
  end

  @doc """
  Edits the original interaction response (typically after deferring).

  ## Examples

      edit_response(interaction, "Done!")
      edit_response(interaction, content: "Updated!", embeds: [embed])
  """
  @spec edit_response(interaction(), String.t() | keyword()) :: {:ok, map()} | {:error, term()}
  def edit_response(interaction, content) when is_binary(content) do
    edit_response(interaction, content: content)
  end

  def edit_response(interaction, opts) when is_list(opts) do
    app_id = interaction["application_id"] || app_id()
    {files, opts} = Keyword.pop(opts, :files, [])
    data = build_message_data(opts)

    EDA.API.Interaction.edit_response(app_id, interaction["token"], data, files)
  end

  @doc """
  Sends a followup message to the interaction.

  ## Examples

      followup(interaction, "Another message!")
      followup(interaction, content: "Followup", ephemeral: true)
  """
  @spec followup(interaction(), String.t() | keyword()) :: {:ok, map()} | {:error, term()}
  def followup(interaction, content) when is_binary(content) do
    followup(interaction, content: content)
  end

  def followup(interaction, opts) when is_list(opts) do
    app_id = interaction["application_id"] || app_id()
    {files, opts} = Keyword.pop(opts, :files, [])
    data = build_message_data(opts)

    EDA.API.Interaction.create_followup(app_id, interaction["token"], data, files)
  end

  @doc "Deletes the original interaction response."
  @spec delete_response(interaction()) :: :ok | {:error, term()}
  def delete_response(interaction) do
    app_id = interaction["application_id"] || app_id()

    EDA.API.Interaction.delete_response(app_id, interaction["token"])
  end

  @doc """
  Responds to an interaction by opening a modal dialog.

  Takes a modal map built with `EDA.Modal.modal/3+`.

  ## Example

      import EDA.Modal

      modal =
        modal("feedback", "Feedback",
          text_input("subject", "Subject", :short),
          text_input("body", "Details", :paragraph)
        )

      respond_modal(interaction, modal)
  """
  @spec respond_modal(interaction(), map()) :: :ok | {:error, term()}
  def respond_modal(interaction, modal) when is_map(modal) do
    payload = %{type: 9, data: modal}

    EDA.API.Interaction.respond(
      interaction["id"],
      interaction["token"],
      payload
    )
  end

  @doc """
  Responds with autocomplete results.

  Takes a list of `{name, value}` tuples (max 25).

  ## Example

      autocomplete(interaction, [
        {"Option A", "a"},
        {"Option B", "b"}
      ])
  """
  @spec autocomplete(interaction(), [{String.t(), term()}]) :: :ok | {:error, term()}
  def autocomplete(interaction, choices) when is_list(choices) do
    parsed = Enum.map(choices, fn {name, value} -> %{name: name, value: value} end)
    payload = %{type: 8, data: %{choices: parsed}}

    EDA.API.Interaction.respond(
      interaction["id"],
      interaction["token"],
      payload
    )
  end

  # ── Private ─────────────────────────────────────────────────────────

  defp get_flat_options(%{data: %{"options" => options}}) when is_list(options) do
    flatten_options(options)
  end

  defp get_flat_options(%{"data" => %{"options" => options}}) when is_list(options) do
    flatten_options(options)
  end

  defp get_flat_options(_), do: []

  defp flatten_options(options) do
    Enum.flat_map(options, fn
      %{"type" => type, "options" => nested} when type in [1, 2] and is_list(nested) ->
        flatten_options(nested)

      opt ->
        [opt]
    end)
  end

  defp build_message_data(opts) do
    data = %{}

    data = if opts[:content], do: Map.put(data, :content, opts[:content]), else: data

    data =
      case {opts[:embed], opts[:embeds]} do
        {nil, nil} ->
          data

        {embed, nil} ->
          Map.put(data, :embeds, [maybe_to_map(embed)])

        {nil, embeds} ->
          Map.put(data, :embeds, Enum.map(embeds, &maybe_to_map/1))

        _ ->
          raise ArgumentError, "cannot specify both :embed and :embeds"
      end

    data = put_message_flags(data, opts)
    if opts[:components], do: Map.put(data, :components, opts[:components]), else: data
  end

  defp put_message_flags(data, opts) do
    flags = if(opts[:ephemeral], do: 64, else: 0) + if(opts[:v2], do: 32_768, else: 0)
    if flags > 0, do: Map.put(data, :flags, flags), else: data
  end

  defp maybe_to_map(%EDA.Embed{} = embed), do: EDA.Embed.to_map(embed)
  defp maybe_to_map(map) when is_map(map), do: map

  defp app_id do
    case EDA.Cache.me() do
      %EDA.User{id: id} when not is_nil(id) -> id
      %{"id" => id} when not is_nil(id) -> id
      _ -> raise "application_id not available, bot not connected"
    end
  end
end
