defmodule EDA.Command.Option do
  @moduledoc """
  Builder for command option objects.

  Provides type-specific constructors that produce validated option structs.
  Options are added to commands via `EDA.Command.option/2`.

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

  @enforce_keys [:type, :name, :description]
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
    name_localizations: nil,
    description_localizations: nil
  ]

  @type t :: %__MODULE__{
          type: 1..11,
          name: String.t(),
          description: String.t(),
          required: boolean() | nil,
          choices: [map()] | nil,
          options: [t()] | nil,
          channel_types: [non_neg_integer()] | nil,
          min_value: number() | nil,
          max_value: number() | nil,
          min_length: non_neg_integer() | nil,
          max_length: pos_integer() | nil,
          autocomplete: boolean() | nil
        }

  @option_name_regex ~r/^[-_\p{L}\p{N}]{1,32}$/u

  @channel_type_map %{
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

    %__MODULE__{type: 1, name: name, description: description, options: non_empty(options)}
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
      %__MODULE__{type: 1} ->
        :ok

      other ->
        raise ArgumentError,
              "sub_command_group children must be sub_commands, got: #{inspect(other)}"
    end)

    %__MODULE__{type: 2, name: name, description: description, options: sub_commands}
  end

  @doc "Creates a STRING option (type 3)."
  @spec string(String.t(), String.t(), keyword()) :: t()
  def string(name, description, opts \\ []) do
    build(3, name, description, opts, [
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
    build(4, name, description, opts, [:required, :choices, :autocomplete, :min_value, :max_value])
  end

  @doc "Creates a BOOLEAN option (type 5)."
  @spec boolean(String.t(), String.t(), keyword()) :: t()
  def boolean(name, description, opts \\ []) do
    build(5, name, description, opts, [:required])
  end

  @doc "Creates a USER option (type 6)."
  @spec user(String.t(), String.t(), keyword()) :: t()
  def user(name, description, opts \\ []) do
    build(6, name, description, opts, [:required])
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
    build(7, name, description, opts, [:required, :channel_types])
  end

  @doc "Creates a ROLE option (type 8)."
  @spec role(String.t(), String.t(), keyword()) :: t()
  def role(name, description, opts \\ []) do
    build(8, name, description, opts, [:required])
  end

  @doc "Creates a MENTIONABLE option (type 9) — accepts users or roles."
  @spec mentionable(String.t(), String.t(), keyword()) :: t()
  def mentionable(name, description, opts \\ []) do
    build(9, name, description, opts, [:required])
  end

  @doc "Creates a NUMBER option (type 10) — double-precision float."
  @spec number(String.t(), String.t(), keyword()) :: t()
  def number(name, description, opts \\ []) do
    build(10, name, description, opts, [
      :required,
      :choices,
      :autocomplete,
      :min_value,
      :max_value
    ])
  end

  @doc "Creates an ATTACHMENT option (type 11)."
  @spec attachment(String.t(), String.t(), keyword()) :: t()
  def attachment(name, description, opts \\ []) do
    build(11, name, description, opts, [:required])
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
    map = %{type: opt.type, name: opt.name, description: opt.description}

    map
    |> put_if(:required, opt.required)
    |> put_if(:choices, opt.choices)
    |> put_if(:options, opt.options && Enum.map(opt.options, &to_map/1))
    |> put_if(:channel_types, opt.channel_types)
    |> put_if(:min_value, opt.min_value)
    |> put_if(:max_value, opt.max_value)
    |> put_if(:min_length, opt.min_length)
    |> put_if(:max_length, opt.max_length)
    |> put_if(:autocomplete, opt.autocomplete)
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
            "unexpected options #{inspect(unexpected)} for option type #{type_name(type)}"
    end

    opt = %__MODULE__{type: type, name: name, description: description}
    Enum.reduce(opts, opt, &apply_opt/2)
  end

  defp apply_opt({:required, value}, opt) when is_boolean(value) do
    %{opt | required: value}
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
          %{name: name, value: value}

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
    values =
      Enum.map(types, fn ct ->
        case Map.fetch(@channel_type_map, ct) do
          {:ok, v} -> v
          :error -> raise ArgumentError, "unknown channel type #{inspect(ct)}"
        end
      end)

    %{opt | channel_types: values}
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

  defp type_name(1), do: "SUB_COMMAND"
  defp type_name(2), do: "SUB_COMMAND_GROUP"
  defp type_name(3), do: "STRING"
  defp type_name(4), do: "INTEGER"
  defp type_name(5), do: "BOOLEAN"
  defp type_name(6), do: "USER"
  defp type_name(7), do: "CHANNEL"
  defp type_name(8), do: "ROLE"
  defp type_name(9), do: "MENTIONABLE"
  defp type_name(10), do: "NUMBER"
  defp type_name(11), do: "ATTACHMENT"
end

defimpl Jason.Encoder, for: EDA.Command.Option do
  def encode(option, opts) do
    option
    |> EDA.Command.Option.to_map()
    |> Jason.Encode.map(opts)
  end
end
