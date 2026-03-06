defmodule EDA.File do
  @moduledoc """
  Represents a file to upload to Discord.

  Use the builder functions to create file structs:

      # From binary data
      EDA.File.from_binary(png_data, "image.png")
      EDA.File.from_binary(png_data, "image.png", description: "Alt text", spoiler: true)

      # From a file path
      EDA.File.from_path("/path/to/image.png")
      EDA.File.from_path("/path/to/image.png", name: "custom.png", description: "Alt text")

  Then pass files to message functions:

      EDA.API.Message.create(channel_id, content: "Check this!", files: [file])
  """

  @enforce_keys [:name, :data]
  defstruct [:name, :data, :description, spoiler: false]

  @type t :: %__MODULE__{
          name: String.t(),
          data: binary(),
          description: String.t() | nil,
          spoiler: boolean()
        }

  @max_name_length 260
  @max_description_length 1024

  @doc """
  Creates a file from binary data.

  The `data` argument must be an Elixir binary (`<<...>>`). If you receive data
  as a list of bytes (e.g. from a Rust NIF returning `Vec<u8>`), convert it first
  with `:erlang.list_to_binary/1`:

      # NIF returns [0, 1, 2, ...] (charlist/list) instead of <<0, 1, 2, ...>> (binary)
      data = :erlang.list_to_binary(nif_result)
      EDA.File.from_binary(data, "output.bin")

  ## Options

    * `:description` - Alt text for the file (max 1024 chars)
    * `:spoiler` - If `true`, prefixes the filename with `SPOILER_`
  """
  @spec from_binary(binary(), String.t(), keyword()) :: t()
  def from_binary(data, name, opts \\ []) when is_binary(data) and is_binary(name) do
    validate_name!(name)
    description = opts[:description]
    if description, do: validate_description!(description)

    %__MODULE__{
      name: name,
      data: data,
      description: description,
      spoiler: opts[:spoiler] || false
    }
  end

  @doc """
  Creates a file from a filesystem path.

  Reads the file and extracts the filename from the path.

  ## Options

    * `:name` - Override the filename (defaults to basename of path)
    * `:description` - Alt text for the file (max 1024 chars)
    * `:spoiler` - If `true`, prefixes the filename with `SPOILER_`
  """
  @spec from_path(String.t(), keyword()) :: t()
  def from_path(path, opts \\ []) when is_binary(path) do
    unless File.exists?(path) do
      raise ArgumentError, "file does not exist: #{path}"
    end

    name = opts[:name] || Path.basename(path)
    data = File.read!(path)
    from_binary(data, name, Keyword.delete(opts, :name))
  end

  @doc """
  Returns the effective filename, with `SPOILER_` prefix if spoiler is true.
  """
  @spec effective_name(t()) :: String.t()
  def effective_name(%__MODULE__{name: name, spoiler: true}), do: "SPOILER_" <> name
  def effective_name(%__MODULE__{name: name}), do: name

  # Validations

  defp validate_name!(name) do
    byte_size = byte_size(name)

    if byte_size == 0 do
      raise ArgumentError, "file name cannot be empty"
    end

    if byte_size > @max_name_length do
      raise ArgumentError,
            "file name exceeds #{@max_name_length} characters (got #{byte_size})"
    end
  end

  defp validate_description!(description) when is_binary(description) do
    if String.length(description) > @max_description_length do
      raise ArgumentError,
            "file description exceeds #{@max_description_length} characters"
    end
  end

  defp validate_description!(other) do
    raise ArgumentError, "file description must be a string, got: #{inspect(other)}"
  end
end
