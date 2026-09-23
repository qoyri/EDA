defmodule EDA.Command do
  @moduledoc """
  Builder for Discord Application Commands (slash commands, user commands, message commands).

  Provides a pipe-friendly API with eager validation against Discord's limits.

  ## Example

      import EDA.Command
      import EDA.Command.Option

      # Simple slash command
      ping = slash("ping", "Pings the bot")

      # Command with options
      greet =
        slash("greet", "Greets someone")
        |> option(string("message", "The greeting", required: true))
        |> option(user("target", "Who to greet"))
        |> option(integer("times", "How many times", min_value: 1, max_value: 10))

      # Command with subcommands
      role =
        slash("role", "Manage roles")
        |> option(
          sub_command("add", "Add a role", [
            role("role", "The role to add", required: true),
            user("target", "The user")
          ])
        )
        |> option(
          sub_command("remove", "Remove a role", [
            role("role", "The role to remove", required: true)
          ])
        )

      # Context menu commands
      info = user_command("User Info")
      quote_msg = message_command("Quote Message")

      # Register
      EDA.API.Command.create_guild(guild_id, greet)
      EDA.API.Command.bulk_overwrite_guild(guild_id, [ping, greet, role])
  """

  alias EDA.Command.Option

  use EDA.Event.Access

  defstruct [
    :id,
    :application_id,
    :guild_id,
    :version,
    :name,
    :description,
    :handler,
    type: :slash,
    options: [],
    default_member_permissions: nil,
    nsfw: false,
    contexts: nil,
    integration_types: nil,
    name_localizations: nil,
    description_localizations: nil
  ]

  @type command_type :: :slash | :user | :message | :primary_entry_point
  @type context :: :guild | :bot_dm | :private_channel
  @type integration_type :: :guild_install | :user_install

  @type t :: %__MODULE__{
          id: String.t() | nil,
          application_id: String.t() | nil,
          guild_id: String.t() | nil,
          version: String.t() | nil,
          name: String.t() | nil,
          description: String.t() | nil,
          handler: :app_handler | :discord_launch_activity | integer() | nil,
          type: command_type() | integer(),
          options: [Option.t()],
          default_member_permissions: String.t() | nil,
          nsfw: boolean() | nil,
          contexts: [context() | integer()] | nil,
          integration_types: [integration_type() | integer()] | nil,
          name_localizations: %{String.t() => String.t()} | nil,
          description_localizations: %{String.t() => String.t()} | nil
        }

  @types %{1 => :slash, 2 => :user, 3 => :message, 4 => :primary_entry_point}
  @contexts %{0 => :guild, 1 => :bot_dm, 2 => :private_channel}
  @integration_types %{0 => :guild_install, 1 => :user_install}
  @handlers %{1 => :app_handler, 2 => :discord_launch_activity}

  @doc """
  A registered command as Discord sends it, from `list_global/0` and the other calls below.

      iex> cmd = EDA.Command.from_raw(%{"id" => "1", "name" => "ping", "type" => 1,
      ...>   "contexts" => [0, 1], "integration_types" => [0], "version" => "7"})
      iex> {cmd.type, cmd.contexts, cmd.integration_types, cmd.options}
      {:slash, [:guild, :bot_dm], [:guild_install], []}
  """
  @spec from_raw(map()) :: t()
  def from_raw(%__MODULE__{} = parsed), do: parsed

  def from_raw(raw) when is_map(raw) do
    %__MODULE__{
      id: :maps.get("id", raw, nil),
      application_id: :maps.get("application_id", raw, nil),
      guild_id: :maps.get("guild_id", raw, nil),
      version: :maps.get("version", raw, nil),
      name: :maps.get("name", raw, nil),
      description: :maps.get("description", raw, nil),
      handler: EDA.Enum.name(@handlers, :maps.get("handler", raw, nil)),
      type: EDA.Enum.name(@types, :maps.get("type", raw, nil) || 1),
      options: Enum.map(:maps.get("options", raw, nil) || [], &Option.from_raw/1),
      default_member_permissions: :maps.get("default_member_permissions", raw, nil),
      nsfw: :maps.get("nsfw", raw, nil),
      contexts: names(:maps.get("contexts", raw, nil), @contexts),
      integration_types: names(:maps.get("integration_types", raw, nil), @integration_types),
      name_localizations: :maps.get("name_localizations", raw, nil),
      description_localizations: :maps.get("description_localizations", raw, nil)
    }
  end

  defp names(nil, _table), do: nil
  defp names(list, table), do: Enum.map(list, &EDA.Enum.name(table, &1))

  defp values(nil, _table, _what), do: nil
  defp values(list, table, what), do: Enum.map(list, &EDA.Enum.value!(table, &1, what))

  @command_name_regex ~r/^[-_\p{L}\p{N}]{1,32}$/u

  # ── Constructors ────────────────────────────────────────────────────

  @doc """
  Creates a new slash command (CHAT_INPUT, type 1).

  Name must be 1-32 lowercase characters (a-z, 0-9, -, _).
  Description must be 1-100 characters.
  """
  @spec slash(String.t(), String.t()) :: t()
  def slash(name, description) when is_binary(name) and is_binary(description) do
    validate_slash_name!(name)
    validate_description!(description)
    %__MODULE__{name: name, description: description, type: :slash}
  end

  @doc """
  Creates a user context menu command (type 2).

  Name must be 1-32 characters. Mixed case and spaces allowed.
  """
  @spec user_command(String.t()) :: t()
  def user_command(name) when is_binary(name) do
    validate_name!(name)
    %__MODULE__{name: name, description: "", type: :user}
  end

  @doc """
  Creates a message context menu command (type 3).

  Name must be 1-32 characters. Mixed case and spaces allowed.
  """
  @spec message_command(String.t()) :: t()
  def message_command(name) when is_binary(name) do
    validate_name!(name)
    %__MODULE__{name: name, description: "", type: :message}
  end

  # ── Modifiers ───────────────────────────────────────────────────────

  @doc """
  Adds an option to the command (max 25 options).

  Only valid for slash commands (type 1).
  """
  @spec option(t(), Option.t()) :: t()
  def option(%__MODULE__{type: :slash} = cmd, %Option{} = opt) do
    if length(cmd.options) >= 25 do
      raise ArgumentError, "command cannot have more than 25 options"
    end

    %{cmd | options: cmd.options ++ [opt]}
  end

  def option(%__MODULE__{type: type}, %Option{}) do
    raise ArgumentError, "#{type} commands cannot have options"
  end

  @doc """
  Sets the default member permissions required to use this command.

  Accepts a permission bitfield as a string (e.g. `"8"` for Administrator).
  Use `"0"` to disable for everyone except admins.
  """
  @spec default_member_permissions(t(), String.t()) :: t()
  def default_member_permissions(%__MODULE__{} = cmd, perms) when is_binary(perms) do
    %{cmd | default_member_permissions: perms}
  end

  @doc "Marks the command as age-restricted (NSFW)."
  @spec nsfw(t(), boolean()) :: t()
  def nsfw(%__MODULE__{} = cmd, value \\ true) when is_boolean(value) do
    %{cmd | nsfw: value}
  end

  @doc """
  Sets the interaction contexts where the command can be used.

  Accepts a list of `:guild`, `:bot_dm`, `:private_channel`.

  ## Example

      slash("ping", "Pong") |> contexts([:guild, :bot_dm])
  """
  @spec contexts(t(), [context()]) :: t()
  def contexts(%__MODULE__{} = cmd, ctx_list) when is_list(ctx_list) do
    Enum.each(ctx_list, fn ctx ->
      if ctx not in Map.values(@contexts) do
        raise ArgumentError,
              "unknown context #{inspect(ctx)}, expected :guild, :bot_dm, or :private_channel"
      end
    end)

    %{cmd | contexts: ctx_list}
  end

  @doc """
  Sets where the command can be installed: `:guild_install` (added to a guild) and/or
  `:user_install` (added to a user's account, usable anywhere).

  ## Example

      slash("remind", "Set a reminder") |> integration_types([:guild_install, :user_install])
  """
  @spec integration_types(t(), [integration_type()]) :: t()
  def integration_types(%__MODULE__{} = cmd, types) when is_list(types) do
    Enum.each(types, &EDA.Enum.value!(@integration_types, &1, "integration type"))
    %{cmd | integration_types: types}
  end

  @doc """
  Adds localized name and/or description for a given locale.

  Discord locale codes: `"fr"`, `"de"`, `"es-ES"`, `"ja"`, `"pt-BR"`, etc.
  See [Discord docs](https://discord.com/developers/docs/reference#locales) for the full list.

  ## Examples

      slash("ping", "Pings the bot")
      |> localize("fr", name: "ping", description: "Ping le bot")
      |> localize("de", description: "Pingt den Bot")
  """
  @spec localize(t(), String.t(), keyword()) :: t()
  def localize(%__MODULE__{} = cmd, locale, opts) when is_binary(locale) do
    cmd =
      case Keyword.get(opts, :name) do
        nil ->
          cmd

        name ->
          names = Map.put(cmd.name_localizations || %{}, locale, name)
          %{cmd | name_localizations: names}
      end

    case Keyword.get(opts, :description) do
      nil ->
        cmd

      desc ->
        descs = Map.put(cmd.description_localizations || %{}, locale, desc)
        %{cmd | description_localizations: descs}
    end
  end

  # ── Serialization ───────────────────────────────────────────────────

  @doc "Converts the command struct to a plain map for the Discord API."
  @spec to_map(t()) :: map()
  def to_map(%__MODULE__{} = cmd) do
    %{name: cmd.name, type: EDA.Enum.value!(@types, cmd.type, "command type")}
    |> put_if(:id, cmd.id)
    |> put_if(:description, if(cmd.description != "", do: cmd.description))
    |> put_if(:options, if(cmd.options != [], do: Enum.map(cmd.options, &Option.to_map/1)))
    |> put_if(:default_member_permissions, cmd.default_member_permissions)
    |> put_if(:nsfw, if(cmd.nsfw, do: true))
    |> put_if(:contexts, values(cmd.contexts, @contexts, "context"))
    |> put_if(
      :integration_types,
      values(cmd.integration_types, @integration_types, "integration type")
    )
    |> put_if(:handler, cmd.handler && EDA.Enum.value!(@handlers, cmd.handler, "handler"))
    |> put_if(:name_localizations, cmd.name_localizations)
    |> put_if(:description_localizations, cmd.description_localizations)
  end

  defp put_if(map, _key, nil), do: map
  defp put_if(map, key, value), do: Map.put(map, key, value)

  # ── Entity Manager ──

  @doc "Lists the app's global commands."
  @spec list_global() :: {:ok, [t()]} | {:error, term()}
  def list_global, do: EDA.API.Command.list_global() |> parse_list()

  @doc "Lists the app's commands registered in a guild."
  @spec list_guild(String.t() | integer()) :: {:ok, [t()]} | {:error, term()}
  def list_guild(guild_id), do: EDA.API.Command.list_guild(guild_id) |> parse_list()

  @doc "Registers a global command, built with `slash/2` and the other constructors."
  @spec create_global(t() | map()) :: {:ok, t()} | {:error, term()}
  def create_global(command), do: EDA.API.Command.create_global(command) |> parse_one()

  @doc "Registers a command in a guild."
  @spec create_guild(String.t() | integer(), t() | map()) :: {:ok, t()} | {:error, term()}
  def create_guild(guild_id, command),
    do: EDA.API.Command.create_guild(guild_id, command) |> parse_one()

  @doc "Edits a global command. Takes the command, or its id and the new definition."
  @spec edit_global(t() | String.t() | integer(), t() | map()) :: {:ok, t()} | {:error, term()}
  def edit_global(%__MODULE__{id: id}, command), do: edit_global(id, command)

  def edit_global(command_id, command),
    do: EDA.API.Command.edit_global(command_id, command) |> parse_one()

  @doc "Edits a command registered in a guild."
  @spec edit_guild(String.t() | integer(), t() | String.t() | integer(), t() | map()) ::
          {:ok, t()} | {:error, term()}
  def edit_guild(guild_id, %__MODULE__{id: id}, command), do: edit_guild(guild_id, id, command)

  def edit_guild(guild_id, command_id, command),
    do: EDA.API.Command.edit_guild(guild_id, command_id, command) |> parse_one()

  @doc "Deletes a global command."
  @spec delete_global(t() | String.t() | integer()) :: :ok | {:error, term()}
  def delete_global(%__MODULE__{id: id}), do: delete_global(id)
  def delete_global(command_id), do: EDA.API.Command.delete_global(command_id)

  @doc "Deletes a command registered in a guild."
  @spec delete_guild(String.t() | integer(), t() | String.t() | integer()) ::
          :ok | {:error, term()}
  def delete_guild(guild_id, %__MODULE__{id: id}), do: delete_guild(guild_id, id)
  def delete_guild(guild_id, command_id), do: EDA.API.Command.delete_guild(guild_id, command_id)

  @doc """
  Replaces every global command with `commands`, returning them as registered. A command not in
  the list is deleted; one with the `id` of an existing command updates it.
  """
  @spec bulk_overwrite_global([t() | map()]) :: {:ok, [t()]} | {:error, term()}
  def bulk_overwrite_global(commands),
    do: EDA.API.Command.bulk_overwrite_global(commands) |> parse_list()

  @doc "Replaces every command registered in a guild with `commands`."
  @spec bulk_overwrite_guild(String.t() | integer(), [t() | map()]) ::
          {:ok, [t()]} | {:error, term()}
  def bulk_overwrite_guild(guild_id, commands),
    do: EDA.API.Command.bulk_overwrite_guild(guild_id, commands) |> parse_list()

  @doc "Who may use each of the app's commands in a guild, as `EDA.Command.Permissions` structs."
  @spec permissions(String.t() | integer()) ::
          {:ok, [EDA.Command.Permissions.t()]} | {:error, term()}
  def permissions(guild_id) do
    case EDA.API.Command.permissions(guild_id) do
      {:ok, list} when is_list(list) -> {:ok, Enum.map(list, &EDA.Command.Permissions.from_raw/1)}
      {:error, _} = err -> err
    end
  end

  @doc "Who may use one command in a guild, as an `EDA.Command.Permissions`."
  @spec permissions(String.t() | integer(), t() | String.t() | integer()) ::
          {:ok, EDA.Command.Permissions.t()} | {:error, term()}
  def permissions(guild_id, %__MODULE__{id: id}), do: permissions(guild_id, id)

  def permissions(guild_id, command_id) do
    case EDA.API.Command.permissions(guild_id, command_id) do
      {:ok, raw} when is_map(raw) -> {:ok, EDA.Command.Permissions.from_raw(raw)}
      {:error, _} = err -> err
    end
  end

  defp parse_one({:ok, raw}) when is_map(raw), do: {:ok, from_raw(raw)}
  defp parse_one({:error, _} = err), do: err

  defp parse_list({:ok, list}) when is_list(list), do: {:ok, Enum.map(list, &from_raw/1)}
  defp parse_list({:error, _} = err), do: err

  # ── Private ─────────────────────────────────────────────────────────

  defp validate_slash_name!(name) do
    len = String.length(name)

    if len < 1 or len > 32 do
      raise ArgumentError, "command name must be 1-32 characters, got #{len}"
    end

    unless Regex.match?(@command_name_regex, name) do
      raise ArgumentError,
            "slash command name #{inspect(name)} is invalid, must match #{inspect(@command_name_regex)}"
    end

    if name != String.downcase(name) do
      raise ArgumentError, "slash command name must be lowercase, got #{inspect(name)}"
    end
  end

  defp validate_name!(name) do
    len = String.length(name)

    if len < 1 or len > 32 do
      raise ArgumentError, "command name must be 1-32 characters, got #{len}"
    end
  end

  defp validate_description!(desc) do
    len = String.length(desc)

    if len < 1 or len > 100 do
      raise ArgumentError, "command description must be 1-100 characters, got #{len}"
    end
  end
end

defimpl Jason.Encoder, for: EDA.Command do
  def encode(command, opts) do
    command
    |> EDA.Command.to_map()
    |> Jason.Encode.map(opts)
  end
end
