defmodule EDA.Command.Option do
  @moduledoc """
  Builder for command option objects.

  Provides type-specific constructors that produce validated option structs.
  Options are added to commands via `EDA.Command.option/2`. The same struct is what
  `EDA.Command.from_raw/1` reads a registered command's options into: `type` is an atom named
  after Discord's (`:sub_command`, `:string`, `:channel`…), `channel_types` are channel type
  atoms, and `choices` are `EDA.Command.Option.Choice` structs.

  ## Example

      import EDA.Command.Option

      string("query", "Search query", required: true, min_length: 1, max_length: 100)
      integer("count", "How many", min_value: 1, max_value: 25)
      user("target", "The user to mention")
      channel("channel", "Where to post", channel_types: [:guild_text])

      string("color", "Pick a color",
        required: true,
        choices: [
          {"Red", "red"},
          {"Blue", "blue"},
          {"Green", "green"}
        ]
      )

      sub_command("add", "Add something", [
        string("name", "The name", required: true),
        integer("amount", "How many")
      ])
  """

  use EDA.Event.Access

  alias EDA.Command.Option.Choice

  defstruct [
    :type,
    :name,
    :description,
    required: nil,
    choices: nil,
    options: nil,
    channel_types: nil,
    min_value: nil,
    max_value: nil,
    min_length: nil,
    max_length: nil,
    autocomplete: nil,
    file_types: nil,
    name_localizations: nil,
    description_localizations: nil
  ]

  @type t :: %__MODULE__{
          type: type() | nil,
          name: String.t() | nil,
          description: String.t() | nil,
          required: boolean() | nil,
          choices: [Choice.t()] | nil,
          options: [t()] | nil,
          channel_types: [EDA.Channel.channel_type()] | nil,
          min_value: number() | nil,
          max_value: number() | nil,
          min_length: non_neg_integer() | nil,
          max_length: pos_integer() | nil,
          autocomplete: boolean() | nil,
          file_types: [String.t()] | nil,
          name_localizations: %{String.t() => String.t()} | nil,
          description_localizations: %{String.t() => String.t()} | nil
        }

  @type type ::
          :sub_command
          | :sub_command_group
          | :string
          | :integer
          | :boolean
          | :user
          | :channel
          | :role
          | :mentionable
          | :number
          | :attachment
          | integer()

  @types %{
    1 => :sub_command,
    2 => :sub_command_group,
    3 => :string,
    4 => :integer,
    5 => :boolean,
    6 => :user,
    7 => :channel,
    8 => :role,
    9 => :mentionable,
    10 => :number,
    11 => :attachment
  }

  @doc false
  # Shared with EDA.Interaction.Option.
  def type_name(value), do: EDA.Enum.name(@types, value)

  @doc false
  def type_value(type), do: EDA.Enum.value!(@types, type, "command option type")

  @doc """
  An option of a registered command, as Discord sends it.

      iex> EDA.Command.Option.from_raw(%{"type" => 3, "name" => "q", "description" => "Query",
      ...>   "choices" => [%{"name" => "Red", "value" => "red"}]})
      %EDA.Command.Option{type: :string, name: "q", description: "Query",
        choices: [%EDA.Command.Option.Choice{name: "Red", value: "red"}]}
  """
  @spec from_raw(map()) :: t()
  def from_raw(raw) when is_map(raw) do
    %__MODULE__{
      type: type_name(raw["type"]),
      name: raw["name"],
      description: raw["description"],
      required: raw["required"],
      choices: raw["choices"] && Enum.map(raw["choices"], &Choice.from_raw/1),
      options: raw["options"] && Enum.map(raw["options"], &from_raw/1),
      channel_types:
        raw["channel_types"] && Enum.map(raw["channel_types"], &EDA.Channel.type_name/1),
      min_value: raw["min_value"],
      max_value: raw["max_value"],
      min_length: raw["min_length"],
      max_length: raw["max_length"],
      autocomplete: raw["autocomplete"],
      file_types: raw["file_types"],
      name_localizations: raw["name_localizations"],
      description_localizations: raw["description_localizations"]
    }
  end

  @option_name_regex ~r/^[-_\p{L}\p{N}]{1,32}$/u

  # ── Type Constructors ───────────────────────────────────────────────

  @doc "Creates a SUB_COMMAND option (type 1) with nested options."
  @spec sub_command(String.t(), String.t(), [t()]) :: t()
  def sub_command(name, description, options \\ [])
      when is_binary(name) and is_binary(description) and is_list(options) do
    validate_name!(name)
    validate_description!(description)

    if length(options) > 25 do
      raise ArgumentError, "sub_command cannot have more than 25 options"
    end

    %__MODULE__{
      type: :sub_command,
      name: name,
      description: description,
      options: non_empty(options)
    }
  end

  @doc "Creates a SUB_COMMAND_GROUP option (type 2) containing sub_commands."
  @spec sub_command_group(String.t(), String.t(), [t()]) :: t()
  def sub_command_group(name, description, sub_commands)
      when is_binary(name) and is_binary(description) and is_list(sub_commands) do
    validate_name!(name)
    validate_description!(description)

    if sub_commands == [] do
      raise ArgumentError, "sub_command_group must have at least one sub_command"
    end

    if length(sub_commands) > 25 do
      raise ArgumentError, "sub_command_group cannot have more than 25 sub_commands"
    end

    Enum.each(sub_commands, fn
      %__MODULE__{type: :sub_command} ->
        :ok

      other ->
        raise ArgumentError,
              "sub_command_group children must be sub_commands, got: #{inspect(other)}"
    end)

    %__MODULE__{
      type: :sub_command_group,
      name: name,
      description: description,
      options: sub_commands
    }
  end

  @doc "Creates a STRING option (type 3)."
  @spec string(String.t(), String.t(), keyword()) :: t()
  def string(name, description, opts \\ []) do
    build(:string, name, description, opts, [
      :required,
      :choices,
      :autocomplete,
      :min_length,
      :max_length
    ])
  end

  @doc "Creates an INTEGER option (type 4)."
  @spec integer(String.t(), String.t(), keyword()) :: t()
  def integer(name, description, opts \\ []) do
    build(:integer, name, description, opts, [
      :required,
      :choices,
      :autocomplete,
      :min_value,
      :max_value
    ])
  end

  @doc "Creates a BOOLEAN option (type 5)."
  @spec boolean(String.t(), String.t(), keyword()) :: t()
  def boolean(name, description, opts \\ []) do
    build(:boolean, name, description, opts, [:required])
  end

  @doc "Creates a USER option (type 6)."
  @spec user(String.t(), String.t(), keyword()) :: t()
  def user(name, description, opts \\ []) do
    build(:user, name, description, opts, [:required])
  end

  @doc """
  Creates a CHANNEL option (type 7).

  ## Options

    * `:channel_types` - list of channel type atoms to restrict selection.
      Valid types: `:guild_text`, `:dm`, `:guild_voice`, `:group_dm`,
      `:guild_category`, `:guild_announcement`, `:announcement_thread`,
      `:public_thread`, `:private_thread`, `:guild_stage_voice`,
      `:guild_forum`, `:guild_media`
  """
  @spec channel(String.t(), String.t(), keyword()) :: t()
  def channel(name, description, opts \\ []) do
    build(:channel, name, description, opts, [:required, :channel_types])
  end

  @doc "Creates a ROLE option (type 8)."
  @spec role(String.t(), String.t(), keyword()) :: t()
  def role(name, description, opts \\ []) do
    build(:role, name, description, opts, [:required])
  end

  @doc "Creates a MENTIONABLE option (type 9) — accepts users or roles."
  @spec mentionable(String.t(), String.t(), keyword()) :: t()
  def mentionable(name, description, opts \\ []) do
    build(:mentionable, name, description, opts, [:required])
  end

  @doc "Creates a NUMBER option (type 10) — double-precision float."
  @spec number(String.t(), String.t(), keyword()) :: t()
  def number(name, description, opts \\ []) do
    build(:number, name, description, opts, [
      :required,
      :choices,
      :autocomplete,
      :min_value,
      :max_value
    ])
  end

  @doc """
  Creates an ATTACHMENT option (type 11).

  ## Options

    * `:required` - whether the user must supply a file
    * `:file_types` - up to #{EDA.FileType.max_filters()} filters narrowing the file picker.
      Each is `:image`, `:video`, `:audio` or a dot-prefixed extension — see `EDA.FileType`

  ## Examples

      attachment("avatar", "A picture of you", required: true, file_types: [:image])

      attachment("receipt", "Proof of purchase", file_types: [:image, ".pdf"])

  > #### `:file_types` narrows the picker, it does not validate {: .warning}
  >
  > Discord matches the filename's extension and never inspects the file. Check what you
  > actually received before trusting it.
  """
  @spec attachment(String.t(), String.t(), keyword()) :: t()
  def attachment(name, description, opts \\ []) do
    build(:attachment, name, description, opts, [:required, :file_types])
  end

  @doc """
  Adds localized name and/or description for a given locale.

  ## Examples

      string("query", "Search query")
      |> localize("fr", name: "requête", description: "Requête de recherche")
  """
  @spec localize(t(), String.t(), keyword()) :: t()
  def localize(%__MODULE__{} = opt, locale, opts) when is_binary(locale) do
    opt =
      case Keyword.get(opts, :name) do
        nil ->
          opt

        name ->
          names = Map.put(opt.name_localizations || %{}, locale, name)
          %{opt | name_localizations: names}
      end

    case Keyword.get(opts, :description) do
      nil ->
        opt

      desc ->
        descs = Map.put(opt.description_localizations || %{}, locale, desc)
        %{opt | description_localizations: descs}
    end
  end

  # ── Serialization ───────────────────────────────────────────────────

  @doc "Converts the option struct to a plain map for the Discord API."
  @spec to_map(t()) :: map()
  def to_map(%__MODULE__{} = opt) do
    map = %{type: type_value(opt.type), name: opt.name, description: opt.description}

    map
    |> put_if(:required, opt.required)
    |> put_if(:choices, opt.choices && Enum.map(opt.choices, &choice_map/1))
    |> put_if(:options, opt.options && Enum.map(opt.options, &to_map/1))
    |> put_if(
      :channel_types,
      opt.channel_types && Enum.map(opt.channel_types, &EDA.Channel.type_value/1)
    )
    |> put_if(:min_value, opt.min_value)
    |> put_if(:max_value, opt.max_value)
    |> put_if(:min_length, opt.min_length)
    |> put_if(:max_length, opt.max_length)
    |> put_if(:autocomplete, opt.autocomplete)
    |> put_if(:file_types, opt.file_types)
    |> put_if(:name_localizations, opt.name_localizations)
    |> put_if(:description_localizations, opt.description_localizations)
  end

  # ── Private ─────────────────────────────────────────────────────────

  defp build(type, name, description, opts, allowed_keys)
       when is_binary(name) and is_binary(description) do
    validate_name!(name)
    validate_description!(description)

    unexpected = Keyword.keys(opts) -- allowed_keys

    if unexpected != [] do
      raise ArgumentError,
            "unexpected options #{inspect(unexpected)} for option type #{type |> Atom.to_string() |> String.upcase()}"
    end

    opt = %__MODULE__{type: type, name: name, description: description}
    Enum.reduce(opts, opt, &apply_opt/2)
  end

  defp apply_opt({:required, value}, opt) when is_boolean(value) do
    %{opt | required: value}
  end

  defp apply_opt({:file_types, file_types}, opt) do
    %{opt | file_types: EDA.FileType.normalize!(file_types)}
  end

  defp apply_opt({:choices, choices}, opt) when is_list(choices) do
    if opt.autocomplete do
      raise ArgumentError, "choices and autocomplete are mutually exclusive"
    end

    if length(choices) > 25 do
      raise ArgumentError, "option cannot have more than 25 choices"
    end

    parsed =
      Enum.map(choices, fn
        {name, value} when is_binary(name) ->
          validate_choice_name!(name)
          validate_choice_value!(value)
          %Choice{name: name, value: value}

        other ->
          raise ArgumentError,
                "choice must be a {name, value} tuple, got: #{inspect(other)}"
      end)

    %{opt | choices: parsed}
  end

  defp apply_opt({:autocomplete, value}, opt) when is_boolean(value) do
    if opt.choices do
      raise ArgumentError, "choices and autocomplete are mutually exclusive"
    end

    %{opt | autocomplete: value}
  end

  defp apply_opt({:min_value, value}, opt) when is_number(value) do
    %{opt | min_value: value}
  end

  defp apply_opt({:max_value, value}, opt) when is_number(value) do
    %{opt | max_value: value}
  end

  defp apply_opt({:min_length, value}, opt)
       when is_integer(value) and value >= 0 and value <= 6000 do
    %{opt | min_length: value}
  end

  defp apply_opt({:max_length, value}, opt)
       when is_integer(value) and value >= 1 and value <= 6000 do
    %{opt | max_length: value}
  end

  defp apply_opt({:channel_types, types}, opt) when is_list(types) do
    # Checked now, so an unknown type fails where it is written rather than when sent.
    Enum.each(types, &EDA.Channel.type_value/1)
    %{opt | channel_types: types}
  end

  defp validate_name!(name) do
    len = String.length(name)

    if len < 1 or len > 32 do
      raise ArgumentError, "option name must be 1-32 characters, got #{len}"
    end

    unless Regex.match?(@option_name_regex, name) do
      raise ArgumentError, "option name #{inspect(name)} is invalid"
    end

    if name != String.downcase(name) do
      raise ArgumentError, "option name must be lowercase, got #{inspect(name)}"
    end
  end

  defp validate_description!(desc) do
    len = String.length(desc)

    if len < 1 or len > 100 do
      raise ArgumentError, "option description must be 1-100 characters, got #{len}"
    end
  end

  defp validate_choice_name!(name) do
    len = String.length(name)

    if len < 1 or len > 100 do
      raise ArgumentError, "choice name must be 1-100 characters, got #{len}"
    end
  end

  defp validate_choice_value!(value) when is_binary(value) do
    if String.length(value) > 100 do
      raise ArgumentError, "string choice value must be at most 100 characters"
    end
  end

  defp validate_choice_value!(value) when is_integer(value) or is_float(value), do: :ok

  defp non_empty([]), do: nil
  defp non_empty(list), do: list

  defp put_if(map, _key, nil), do: map
  defp put_if(map, key, value), do: Map.put(map, key, value)

  defp choice_map(%Choice{} = choice), do: Choice.to_map(choice)
  defp choice_map(map) when is_map(map), do: map
end

defimpl Jason.Encoder, for: EDA.Command.Option do
  def encode(option, opts) do
    option
    |> EDA.Command.Option.to_map()
    |> Jason.Encode.map(opts)
  end
end
