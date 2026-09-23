defmodule EDA.Interaction do
  require Logger

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

  alias EDA.Interaction.{CommandData, ComponentData, ModalSubmitData, Option}

  @type interaction :: map()

  # ── Accessors ───────────────────────────────────────────────────────

  @doc "Returns the command name from the interaction data."
  @spec command_name(interaction()) :: String.t() | nil
  def command_name(interaction) do
    case data(interaction) do
      %CommandData{name: name} -> name
      _ -> nil
    end
  end

  @doc """
  Returns the command type as an atom.

  - `:slash` (type 1, CHAT_INPUT)
  - `:user` (type 2, USER context menu)
  - `:message` (type 3, MESSAGE context menu)
  - `:primary_entry_point` (type 4, an activity's launch command)
  """
  @spec command_type(interaction()) ::
          :slash | :user | :message | :primary_entry_point | integer() | nil
  def command_type(interaction) do
    case data(interaction) do
      %CommandData{type: type} -> type
      _ -> nil
    end
  end

  @doc """
  Returns the interaction type as an atom.

  - `:ping` (1)
  - `:command` (2, APPLICATION_COMMAND)
  - `:component` (3, MESSAGE_COMPONENT)
  - `:autocomplete` (4, APPLICATION_COMMAND_AUTOCOMPLETE)
  - `:modal_submit` (5, MODAL_SUBMIT)
  """
  @spec interaction_type(interaction()) :: atom() | nil
  def interaction_type(%{type: type}) when is_atom(type) and not is_nil(type), do: type
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

    case Enum.find(options, &(&1.name == name)) do
      %Option{value: value} when not is_nil(value) -> value
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
    |> Enum.reject(&is_nil(&1.value))
    |> Map.new(&{&1.name, &1.value})
  end

  @doc """
  Returns the sub_command name, or `nil` if not a sub_command invocation.

  For sub_command_groups, returns `{group_name, sub_command_name}`.
  """
  @spec sub_command_name(interaction()) :: String.t() | {String.t(), String.t()} | nil
  def sub_command_name(interaction) do
    case data(interaction) do
      %CommandData{options: [%Option{type: :sub_command_group} = group | _]} ->
        case group.options do
          [%Option{type: :sub_command, name: sub} | _] -> {group.name, sub}
          _ -> nil
        end

      %CommandData{options: [%Option{type: :sub_command, name: name} | _]} ->
        name

      _ ->
        nil
    end
  end

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
  Returns a resolved object by type and ID, as its struct (`EDA.User`, `EDA.Member`,
  `EDA.Role`, `EDA.Channel`, `EDA.Message` or `EDA.Attachment`).

  Types: `:users`, `:members`, `:roles`, `:channels`, `:messages`, `:attachments`, or the
  same as strings.
  """
  @spec resolved(interaction(), atom() | String.t(), String.t()) :: struct() | nil
  def resolved(interaction, type, id), do: interaction |> resolved_map(type) |> Map.get(id)

  @doc """
  Returns the resolved channel with this ID, as an `EDA.Channel` struct.

  Resolved channels are partial: Discord sends `id`, `name`, `type`, `permissions`,
  `app_permissions`, `parent_id`, `guild_id`, `flags`, `nsfw`, `position`, `topic`,
  `rate_limit_per_user`, `last_message_id` and `last_pin_timestamp`, and nothing else.
  Everything absent is `nil` on the struct rather than missing.

      channel_id = get_option(interaction, "destination")
      channel = EDA.Interaction.resolved_channel(interaction, channel_id)
  """
  @spec resolved_channel(interaction(), String.t()) :: EDA.Channel.t() | nil
  def resolved_channel(interaction, channel_id) do
    resolved(interaction, :channels, channel_id)
  end

  @doc """
  Returns every resolved channel as an `EDA.Channel` struct.

  Empty when the command took no channel option.
  """
  @spec resolved_channels(interaction()) :: [EDA.Channel.t()]
  def resolved_channels(interaction) do
    interaction |> resolved_map(:channels) |> Map.values()
  end

  @doc """
  Returns the permissions the **bot** holds, as a bitset.

  With one argument, this is what Discord computed for the channel the interaction came
  from. With a channel id, it is the bot's permissions in that *resolved* channel — the one
  a `CHANNEL` option named — which is usually a different channel from the one the command
  was typed in.

  Discord computes both and sends them with the interaction, so this answers "may I post
  there?" with no REST call and no permission arithmetic. `EDA.Permission.in_channel/3` remains
  the answer for a channel Discord did not resolve.

      # the channel the user picked, not the one they typed in
      destination = get_option(interaction, "destination")

      if EDA.Interaction.can?(interaction, destination, :send_messages) do
        EDA.API.Message.create(destination, content: "Posted!")
      else
        respond(interaction, "I cannot post there.", ephemeral: true)
      end

  Returns `nil` when the field is absent — a channel that was not resolved, an interaction
  from a context where Discord did not send it, or an app installed to a user rather than to
  the guild, since Discord only computes a channel's `app_permissions` when the bot is a
  member of that guild.

  `nil` is not `0`. Being told nothing is not the same as being denied everything, so the
  two are kept apart; `can?/2` treats both as "no".
  """
  @spec app_permissions(interaction()) :: integer() | nil
  def app_permissions(%{app_permissions: value}), do: parse_bitset(value)
  def app_permissions(%{"app_permissions" => value}), do: parse_bitset(value)
  def app_permissions(_interaction), do: nil

  @doc "Returns the bot's permissions in a resolved channel, as a bitset. See `app_permissions/1`."
  @spec app_permissions(interaction(), String.t()) :: integer() | nil
  def app_permissions(interaction, channel_id) do
    interaction
    |> resolved("channels", channel_id)
    |> extract_bitset("app_permissions")
  end

  @doc """
  Returns the permissions the **invoking user** holds, as a bitset.

  With one argument, this is what Discord computed for them in the channel the interaction
  came from — it rides along on the interaction's `member`. With a channel id, it is their
  permissions in that *resolved* channel.

  Discord computes both alongside the bot's, which is what makes "you cannot do that here"
  answerable without fetching the member and their roles.

      if EDA.Interaction.user_can?(interaction, destination, :manage_messages) do
        # ...
      end

  `nil` outside a guild, since a DM has no member.
  """
  @spec user_permissions(interaction()) :: integer() | nil
  def user_permissions(%{member: %EDA.Member{permissions: value}}), do: parse_bitset(value)
  def user_permissions(%{member: %{"permissions" => value}}), do: parse_bitset(value)
  def user_permissions(%{"member" => %{"permissions" => value}}), do: parse_bitset(value)
  def user_permissions(_interaction), do: nil

  @doc "Returns the invoking user's permissions in a resolved channel. See `user_permissions/1`."
  @spec user_permissions(interaction(), String.t()) :: integer() | nil
  def user_permissions(interaction, channel_id) do
    interaction
    |> resolved("channels", channel_id)
    |> extract_bitset("permissions")
  end

  @doc """
  Returns `true` if the bot holds a permission.

  `can?/2` asks about the channel the interaction came from, `can?/3` about a resolved
  channel. An absent bitset is `false`: not being told is not permission.

  ## Examples

      can?(interaction, :embed_links)
      can?(interaction, channel_id, :send_messages)
  """
  @spec can?(interaction(), EDA.Permission.flag()) :: boolean()
  def can?(interaction, flag) do
    holds?(app_permissions(interaction), flag)
  end

  @doc "Returns `true` if the bot holds a permission in a resolved channel. See `can?/2`."
  @spec can?(interaction(), String.t(), EDA.Permission.flag()) :: boolean()
  def can?(interaction, channel_id, flag) do
    holds?(app_permissions(interaction, channel_id), flag)
  end

  @doc """
  Returns `true` if the invoking user holds a permission.

  `user_can?/2` asks about the channel the interaction came from, `user_can?/3` about a
  resolved channel. See `user_permissions/1`.
  """
  @spec user_can?(interaction(), EDA.Permission.flag()) :: boolean()
  def user_can?(interaction, flag) do
    holds?(user_permissions(interaction), flag)
  end

  @doc "Returns `true` if the invoking user holds a permission in a resolved channel."
  @spec user_can?(interaction(), String.t(), EDA.Permission.flag()) :: boolean()
  def user_can?(interaction, channel_id, flag) do
    holds?(user_permissions(interaction, channel_id), flag)
  end

  @doc """
  Names every permission the bot holds, for the interaction's channel or a resolved one.

  Handy in an error message or a log line, where the bitset says nothing.

  ## Examples

      permission_list(interaction)
      permission_list(interaction, channel_id)
  """
  @spec permission_list(interaction()) :: [EDA.Permission.flag()]
  def permission_list(interaction), do: list_of(app_permissions(interaction))

  @doc "Names the bot's permissions in a resolved channel. See `permission_list/1`."
  @spec permission_list(interaction(), String.t()) :: [EDA.Permission.flag()]
  def permission_list(interaction, channel_id),
    do: list_of(app_permissions(interaction, channel_id))

  @resolved_keys %{
    "users" => :users,
    "members" => :members,
    "roles" => :roles,
    "channels" => :channels,
    "messages" => :messages,
    "attachments" => :attachments
  }

  defp resolved_map(interaction, key) when is_binary(key),
    do: resolved_map(interaction, Map.get(@resolved_keys, key))

  defp resolved_map(interaction, key) do
    case data(interaction) do
      %{resolved: %EDA.Resolved{} = resolved} when is_atom(key) and not is_nil(key) ->
        Map.get(resolved, key, %{})

      _ ->
        %{}
    end
  end

  defp extract_bitset(nil, _key), do: nil
  defp extract_bitset(raw, key) when is_map(raw), do: parse_bitset(raw[key])

  # Discord sends permission bitsets as strings, because they exceed 53 bits.
  defp parse_bitset(nil), do: nil
  defp parse_bitset(value) when is_integer(value), do: value

  defp parse_bitset(value) when is_binary(value) do
    case Integer.parse(value) do
      {bitset, ""} -> bitset
      _other -> nil
    end
  end

  defp parse_bitset(_other), do: nil

  defp holds?(nil, _flag), do: false
  defp holds?(bitset, flag), do: EDA.Permission.has?(bitset, flag)

  defp list_of(nil), do: []
  defp list_of(bitset), do: EDA.Permission.to_list(bitset)

  @doc """
  Returns the target ID for user/message context menu commands.
  """
  @spec target_id(interaction()) :: String.t() | nil
  def target_id(interaction) do
    case data(interaction) do
      %CommandData{target_id: id} -> id
      _ -> nil
    end
  end

  @doc "Returns the custom_id for component interactions and modal submits."
  @spec custom_id(interaction()) :: String.t() | nil
  def custom_id(interaction) do
    case data(interaction) do
      %ComponentData{custom_id: id} -> id
      %ModalSubmitData{custom_id: id} -> id
      _ -> nil
    end
  end

  @doc """
  Returns the selected values from a select menu interaction.

  Returns an empty list if the interaction is not a select menu.

  ## Examples

      values = EDA.Interaction.selected_values(interaction)
      # => ["option_1", "option_2"]
  """
  @spec selected_values(interaction()) :: [String.t()]
  def selected_values(interaction) do
    case data(interaction) do
      %ComponentData{values: values} when is_list(values) -> values
      _ -> []
    end
  end

  @doc """
  Returns the component type for a message component interaction.

  Returns `nil` if not a component interaction.

  The kind is named as in `EDA.Component`: `:button`, `:string_select`, `:user_select`,
  `:role_select`, `:mentionable_select`, `:channel_select`.

  ## Examples

      case EDA.Interaction.component_type(interaction) do
        :button -> handle_button(interaction)
        :string_select -> handle_select(interaction)
        _ -> :ignore
      end
  """
  @spec component_type(interaction()) :: EDA.Component.type() | nil
  def component_type(interaction) do
    case data(interaction) do
      %ComponentData{component_type: type} -> type
      _ -> nil
    end
  end

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
    {delete_after, opts} = Keyword.pop(opts, :delete_after)
    {files, opts} = Keyword.pop(opts, :files, [])
    data = build_message_data(opts)
    payload = %{type: 4, data: data}

    result =
      EDA.API.Interaction.respond(
        interaction["id"],
        interaction["token"],
        payload,
        files
      )

    if result == :ok and is_integer(delete_after) do
      app_id = interaction["application_id"] || app_id()
      token = interaction["token"]
      EDA.AutoDelete.schedule_interaction_response(app_id, token, delete_after)
    end

    result
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
  @spec edit_response(interaction(), String.t() | keyword()) ::
          {:ok, EDA.Message.t()} | {:error, term()}
  def edit_response(interaction, content) when is_binary(content) do
    edit_response(interaction, content: content)
  end

  def edit_response(interaction, opts) when is_list(opts) do
    app_id = interaction["application_id"] || app_id()
    {files, opts} = Keyword.pop(opts, :files, [])
    data = build_message_data(opts)

    EDA.API.Interaction.edit_response(app_id, interaction["token"], data, files)
    |> parse_message()
  end

  @doc """
  Sends a followup message to the interaction.

  ## Examples

      followup(interaction, "Another message!")
      followup(interaction, content: "Followup", ephemeral: true)
  """
  @spec followup(interaction(), String.t() | keyword()) ::
          {:ok, EDA.Message.t()} | {:error, term()}
  def followup(interaction, content) when is_binary(content) do
    followup(interaction, content: content)
  end

  def followup(interaction, opts) when is_list(opts) do
    app_id = interaction["application_id"] || app_id()
    {delete_after, opts} = Keyword.pop(opts, :delete_after)
    {files, opts} = Keyword.pop(opts, :files, [])
    data = build_message_data(opts)

    result = EDA.API.Interaction.create_followup(app_id, interaction["token"], data, files)

    with {:ok, %{"id" => msg_id}} <- result,
         true <- is_integer(delete_after) do
      channel_id = interaction["channel_id"] || Map.get(interaction, :channel_id)
      EDA.AutoDelete.schedule(to_string(channel_id), msg_id, delete_after)
    end

    parse_message(result)
  end

  @doc """
  Edits a followup message sent with `followup/2`. Takes the message or its id, and the options
  of `followup/2`.
  """
  @spec edit_followup(interaction(), EDA.Message.t() | String.t(), String.t() | keyword()) ::
          {:ok, EDA.Message.t()} | {:error, term()}
  def edit_followup(interaction, %EDA.Message{id: id}, opts),
    do: edit_followup(interaction, id, opts)

  def edit_followup(interaction, message_id, content) when is_binary(content),
    do: edit_followup(interaction, message_id, content: content)

  def edit_followup(interaction, message_id, opts) when is_list(opts) do
    app_id = interaction["application_id"] || app_id()
    {files, opts} = Keyword.pop(opts, :files, [])

    app_id
    |> EDA.API.Interaction.edit_followup(
      interaction["token"],
      message_id,
      build_message_data(opts),
      files
    )
    |> parse_message()
  end

  @doc "Deletes a followup message. Takes the message or its id."
  @spec delete_followup(interaction(), EDA.Message.t() | String.t()) :: :ok | {:error, term()}
  def delete_followup(interaction, %EDA.Message{id: id}), do: delete_followup(interaction, id)

  def delete_followup(interaction, message_id) do
    app_id = interaction["application_id"] || app_id()
    EDA.API.Interaction.delete_followup(app_id, interaction["token"], message_id)
  end

  defp parse_message({:ok, raw}) when is_map(raw), do: {:ok, EDA.Message.from_raw(raw)}
  defp parse_message(other), do: other

  @doc "Deletes the original interaction response."
  @spec delete_response(interaction()) :: :ok | {:error, term()}
  def delete_response(interaction) do
    app_id = interaction["application_id"] || app_id()

    EDA.API.Interaction.delete_response(app_id, interaction["token"])
  end

  @doc """
  Deletes the message that triggered a component interaction.

  Works for both ephemeral and non-ephemeral messages. Uses Discord's
  type 6 (DEFERRED_UPDATE_MESSAGE) to claim ownership of the source message,
  then deletes it via `delete_response`.

  **Important:** After calling `delete_source/1`, the interaction is already
  acknowledged. Use `followup/2` instead of `respond/2` for any reply:

      # Correct pattern:
      delete_source(interaction)
      followup(interaction, content: "Done!", ephemeral: true)

      # WRONG — will fail because interaction is already acknowledged:
      delete_source(interaction)
      respond(interaction, "Done!")

  ## Examples

      # User clicks "Confirm" button → delete the prompt, show next step
      EDA.Interaction.delete_source(interaction)
      EDA.Interaction.followup(interaction, content: "Next step...", components: [select_menu])
  """
  @spec delete_source(interaction()) :: :ok | {:error, term()}
  def delete_source(interaction) do
    id = interaction["id"] || Map.get(interaction, :id)
    token = interaction["token"] || Map.get(interaction, :token)

    if id && token do
      with :ok <- EDA.API.Interaction.respond(id, token, %{type: 6}) do
        delete_response(interaction)
      end
    else
      {:error, :no_source_message}
    end
  end

  @doc """
  Defers the interaction, runs the given function, then edits the response.

  Wraps the common `defer → do work → edit_response` pattern in a single call.
  The function receives no arguments and should return a string or keyword list
  suitable for `edit_response/2`.

  ## Options

    * `:ephemeral` — if `true`, the thinking indicator and response are ephemeral

  ## Examples

      EDA.Interaction.defer_and_edit(interaction, fn ->
        result = do_heavy_work()
        "Result: \#{result}"
      end)

      EDA.Interaction.defer_and_edit(interaction, fn ->
        data = fetch_data()
        [content: "Here's your data", embeds: [build_embed(data)]]
      end, ephemeral: true)
  """
  @spec defer_and_edit(interaction(), (-> String.t() | keyword()), keyword()) ::
          {:ok, map()} | {:error, term()}
  def defer_and_edit(interaction, fun, opts \\ []) when is_function(fun, 0) do
    with :ok <- defer(interaction, opts) do
      try do
        edit_response(interaction, fun.())
      rescue
        e ->
          Logger.error("defer_and_edit callback crashed: #{Exception.message(e)}")
          edit_response(interaction, "An error occurred.")
      end
    end
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

  @doc false
  # The interaction's data as its struct, from an INTERACTION_CREATE event or a raw interaction
  # map. A raw map without a type has its data's kind told from its shape.
  @spec data(interaction()) :: struct() | map() | nil
  def data(%{data: %_{} = data}), do: data
  def data(%{data: raw} = interaction) when is_map(raw), do: parse_data(interaction, raw)
  def data(%{"data" => raw} = interaction) when is_map(raw), do: parse_data(interaction, raw)
  def data(_interaction), do: nil

  defp parse_data(interaction, raw) do
    type =
      interaction_type(interaction) ||
        cond do
          Map.has_key?(raw, "components") -> :modal_submit
          Enum.any?(~w(custom_id component_type values), &Map.has_key?(raw, &1)) -> :component
          true -> :command
        end

    EDA.Event.InteractionCreate.parse_data(type, raw)
  end

  defp get_flat_options(interaction) do
    case data(interaction) do
      %CommandData{options: options} when is_list(options) -> flatten_options(options)
      _ -> []
    end
  end

  defp flatten_options(options) do
    Enum.flat_map(options, fn
      %Option{type: type, options: nested}
      when type in [:sub_command, :sub_command_group] and is_list(nested) ->
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
      _ -> raise "application_id not available, bot not connected"
    end
  end
end
