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

  @enforce_keys [:name, :type]
  defstruct [
    :name,
    :description,
    type: 1,
    options: [],
    default_member_permissions: nil,
    nsfw: false,
    contexts: nil,
    name_localizations: nil,
    description_localizations: nil
  ]

  @type command_type :: :slash | :user | :message
  @type context :: :guild | :bot_dm | :private_channel

  @type t :: %__MODULE__{
          name: String.t(),
          description: String.t() | nil,
          type: 1 | 2 | 3,
          options: [Option.t()],
          default_member_permissions: String.t() | nil,
          nsfw: boolean(),
          contexts: [non_neg_integer()] | nil,
          name_localizations: map() | nil,
          description_localizations: map() | nil
        }

  @command_name_regex ~r/^[-_\p{L}\p{N}]{1,32}$/u

  @context_map %{
    guild: 0,
    bot_dm: 1,
    private_channel: 2
  }

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
    %__MODULE__{name: name, description: description, type: 1}
  end

  @doc """
  Creates a user context menu command (type 2).

  Name must be 1-32 characters. Mixed case and spaces allowed.
  """
  @spec user_command(String.t()) :: t()
  def user_command(name) when is_binary(name) do
    validate_name!(name)
    %__MODULE__{name: name, description: "", type: 2}
  end

  @doc """
  Creates a message context menu command (type 3).

  Name must be 1-32 characters. Mixed case and spaces allowed.
  """
  @spec message_command(String.t()) :: t()
  def message_command(name) when is_binary(name) do
    validate_name!(name)
    %__MODULE__{name: name, description: "", type: 3}
  end

  # ── Modifiers ───────────────────────────────────────────────────────

  @doc """
  Adds an option to the command (max 25 options).

  Only valid for slash commands (type 1).
  """
  @spec option(t(), Option.t()) :: t()
  def option(%__MODULE__{type: 1} = cmd, %Option{} = opt) do
    if length(cmd.options) >= 25 do
      raise ArgumentError, "command cannot have more than 25 options"
    end

    %{cmd | options: cmd.options ++ [opt]}
  end

  def option(%__MODULE__{type: type}, %Option{}) do
    type_name = if type == 2, do: "user", else: "message"
    raise ArgumentError, "#{type_name} commands cannot have options"
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
    values =
      Enum.map(ctx_list, fn ctx ->
        case Map.fetch(@context_map, ctx) do
          {:ok, v} ->
            v

          :error ->
            raise ArgumentError,
                  "unknown context #{inspect(ctx)}, expected :guild, :bot_dm, or :private_channel"
        end
      end)

    %{cmd | contexts: values}
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
    map = %{name: cmd.name, type: cmd.type}

    map =
      if cmd.description != "" do
        Map.put(map, :description, cmd.description)
      else
        map
      end

    map =
      if cmd.options != [] do
        Map.put(map, :options, Enum.map(cmd.options, &Option.to_map/1))
      else
        map
      end

    map =
      if cmd.default_member_permissions do
        Map.put(map, :default_member_permissions, cmd.default_member_permissions)
      else
        map
      end

    map = if cmd.nsfw, do: Map.put(map, :nsfw, true), else: map

    map =
      if cmd.contexts do
        Map.put(map, :contexts, cmd.contexts)
      else
        map
      end

    map =
      if cmd.name_localizations do
        Map.put(map, :name_localizations, cmd.name_localizations)
      else
        map
      end

    if cmd.description_localizations do
      Map.put(map, :description_localizations, cmd.description_localizations)
    else
      map
    end
  end

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
