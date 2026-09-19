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

  Accepts both Elixir binaries (`<<...>>`) and byte lists (`[0, 1, 2, ...]`).
  Lists are automatically converted — this is useful when receiving data from
  Rust NIFs that return `Vec<u8>` (Rustler converts these to Erlang lists).

  ## Options

    * `:description` - Alt text for the file (max 1024 chars)
    * `:spoiler` - If `true`, Discord blurs the file until clicked
  """
  @spec from_binary(binary() | list(), String.t(), keyword()) :: t()
  def from_binary(data, name, opts \\ [])

  def from_binary(data, name, opts) when is_list(data) do
    from_binary(:erlang.list_to_binary(data), name, opts)
  end

  def from_binary(data, name, opts) when is_binary(data) and is_binary(name) do
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
    * `:spoiler` - If `true`, Discord blurs the file until clicked
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
  Returns the filename Discord should show.

  This is the name as given. Spoilering used to be requested by prefixing the filename with
  `SPOILER_`, which meant the prefix was visible in the name forever after; EDA now sets the
  `is_spoiler` field of the attachment request instead, so `:spoiler` no longer rewrites the
  name. `EDA.Attachment.spoiler?/1` reads the resulting flag back.

  A name you prefix yourself still works — Discord honours the convention — and is left
  alone.
  """
  @spec effective_name(t()) :: String.t()
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
