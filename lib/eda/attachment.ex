defmodule EDA.Attachment do
  @moduledoc """
  Represents a Discord message attachment.

  Attachments are read off a message:

      for attachment <- message.attachments do
        if EDA.Attachment.spoiler?(attachment), do: IO.puts("blurred: " <> attachment.filename)
      end

  and written back through the `:attachments` array of a message edit — see `keep/2`.

  ## Editing a message's attachments is destructive

  Discord treats the `attachments` array as the **complete** list the message should end up
  with. Anything you leave out is deleted. Uploading one new file to a message that already
  has three therefore removes those three unless you name them:

      {:ok, message} = EDA.Message.fetch_message(channel_id, message_id)

      EDA.Message.edit(message,
        attachments: Enum.map(message.attachments, &EDA.Attachment.keep/1),
        files: [EDA.File.from_path("extra.png")]
      )

  `EDA.Message.edit/2` accepts `attachments: :keep` as shorthand for that first line, which
  costs nothing because the struct already carries them.
  """
  use EDA.Event.Access

  import Bitwise

  defstruct [
    :id,
    :filename,
    :title,
    :description,
    :content_type,
    :size,
    :url,
    :proxy_url,
    :height,
    :width,
    :placeholder,
    :placeholder_version,
    :ephemeral,
    :duration_secs,
    :waveform,
    :flags,
    :clip_participants,
    :clip_created_at,
    :application
  ]

  @type t :: %__MODULE__{
          id: String.t() | nil,
          filename: String.t() | nil,
          title: String.t() | nil,
          description: String.t() | nil,
          content_type: String.t() | nil,
          size: integer() | nil,
          url: String.t() | nil,
          proxy_url: String.t() | nil,
          height: integer() | nil,
          width: integer() | nil,
          placeholder: String.t() | nil,
          placeholder_version: integer() | nil,
          ephemeral: boolean() | nil,
          duration_secs: number() | nil,
          waveform: String.t() | nil,
          flags: integer() | nil,
          clip_participants: [EDA.User.t()] | nil,
          clip_created_at: DateTime.t() | nil,
          application: EDA.App.t() | nil
        }

  @max_description_length 1024

  @spec from_raw(map()) :: t()
  def from_raw(%__MODULE__{} = parsed), do: parsed

  def from_raw(raw) when is_map(raw) do
    %__MODULE__{
      id: :maps.get("id", raw, nil),
      filename: :maps.get("filename", raw, nil),
      title: :maps.get("title", raw, nil),
      description: :maps.get("description", raw, nil),
      content_type: :maps.get("content_type", raw, nil),
      size: :maps.get("size", raw, nil),
      url: :maps.get("url", raw, nil),
      proxy_url: :maps.get("proxy_url", raw, nil),
      height: :maps.get("height", raw, nil),
      width: :maps.get("width", raw, nil),
      placeholder: :maps.get("placeholder", raw, nil),
      placeholder_version: :maps.get("placeholder_version", raw, nil),
      ephemeral: :maps.get("ephemeral", raw, nil),
      duration_secs: :maps.get("duration_secs", raw, nil),
      waveform: :maps.get("waveform", raw, nil),
      flags: :maps.get("flags", raw, nil),
      clip_participants: parse_users(:maps.get("clip_participants", raw, nil)),
      clip_created_at: EDA.Timestamp.parse(:maps.get("clip_created_at", raw, nil)),
      application:
        :maps.get("application", raw, nil) && EDA.App.from_raw(:maps.get("application", raw, nil))
    }
  end

  # ── Flags ──

  @flag_clip 1 <<< 0
  @flag_thumbnail 1 <<< 1
  @flag_remix 1 <<< 2
  @flag_spoiler 1 <<< 3
  @flag_animated 1 <<< 5

  @attachment_flags %{
    clip: @flag_clip,
    thumbnail: @flag_thumbnail,
    remix: @flag_remix,
    spoiler: @flag_spoiler,
    animated: @flag_animated
  }

  @typedoc "An attachment flag name."
  @type flag :: :clip | :thumbnail | :remix | :spoiler | :animated

  @doc "This attachment is a Clip from a stream (`1 <<< 0`)."
  @spec flag_clip() :: integer()
  def flag_clip, do: @flag_clip

  @doc "This attachment is the thumbnail of a thread in a media channel (`1 <<< 1`)."
  @spec flag_thumbnail() :: integer()
  def flag_thumbnail, do: @flag_thumbnail

  @doc "This attachment was edited with the remix feature on mobile (`1 <<< 2`)."
  @spec flag_remix() :: integer()
  def flag_remix, do: @flag_remix

  @doc "This attachment is blurred until clicked (`1 <<< 3`)."
  @spec flag_spoiler() :: integer()
  def flag_spoiler, do: @flag_spoiler

  @doc "This attachment is an animated image (`1 <<< 5`)."
  @spec flag_animated() :: integer()
  def flag_animated, do: @flag_animated

  @doc "Every flag name EDA knows about."
  @spec all_flags() :: [flag()]
  def all_flags, do: Map.keys(@attachment_flags)

  @doc """
  Returns `true` if the given flag is set.

  Accepts a `t:t/0`, a raw attachment map, a bitfield, or `nil`.

  ## Examples

      iex> EDA.Attachment.has_flag?(%EDA.Attachment{flags: 1 <<< 3}, :spoiler)
      true

      iex> EDA.Attachment.has_flag?(%{"flags" => 0}, :spoiler)
      false

      iex> EDA.Attachment.has_flag?(nil, :spoiler)
      false
  """
  @spec has_flag?(t() | map() | integer() | nil, flag()) :: boolean()
  def has_flag?(attachment, flag)

  def has_flag?(%__MODULE__{flags: flags}, flag), do: has_flag?(flags, flag)
  def has_flag?(%{"flags" => flags}, flag), do: has_flag?(flags, flag)

  def has_flag?(bitfield, flag) when is_integer(bitfield) do
    case Map.get(@attachment_flags, flag) do
      nil -> false
      value -> (bitfield &&& value) == value
    end
  end

  def has_flag?(_attachment, _flag), do: false

  @doc """
  Returns the set flags as a list of names, ignoring bits EDA does not know.

  ## Examples

      iex> EDA.Attachment.flag_list(%EDA.Attachment{flags: (1 <<< 3) + (1 <<< 0)})
      [:clip, :spoiler]

      iex> EDA.Attachment.flag_list(nil)
      []
  """
  @spec flag_list(t() | map() | integer() | nil) :: [flag()]
  def flag_list(attachment)

  def flag_list(%__MODULE__{flags: flags}), do: flag_list(flags)
  def flag_list(%{"flags" => flags}), do: flag_list(flags)

  def flag_list(bitfield) when is_integer(bitfield) do
    @attachment_flags
    |> Enum.filter(fn {_name, value} -> (bitfield &&& value) == value end)
    |> Enum.map(&elem(&1, 0))
    |> Enum.sort()
  end

  def flag_list(_attachment), do: []

  @doc """
  Returns `true` if this attachment is blurred until clicked.

  Reads the `IS_SPOILER` flag rather than looking for a `SPOILER_` filename prefix. The
  prefix is the older way of *asking* for a spoiler; the flag is what Discord actually
  reports back, and it is set whichever way the attachment was uploaded.

  ## Examples

      iex> EDA.Attachment.spoiler?(%EDA.Attachment{flags: 1 <<< 3})
      true

      iex> EDA.Attachment.spoiler?(%EDA.Attachment{filename: "SPOILER_x.png", flags: 0})
      false
  """
  @spec spoiler?(t() | map() | integer() | nil) :: boolean()
  def spoiler?(attachment), do: has_flag?(attachment, :spoiler)

  @doc "Returns `true` if this attachment is a Clip from a stream."
  @spec clip?(t() | map() | integer() | nil) :: boolean()
  def clip?(attachment), do: has_flag?(attachment, :clip)

  @doc "Returns `true` if this attachment is a media channel thread's thumbnail."
  @spec thumbnail?(t() | map() | integer() | nil) :: boolean()
  def thumbnail?(attachment), do: has_flag?(attachment, :thumbnail)

  @doc "Returns `true` if this attachment was edited with the mobile remix feature."
  @spec remix?(t() | map() | integer() | nil) :: boolean()
  def remix?(attachment), do: has_flag?(attachment, :remix)

  @doc "Returns `true` if this attachment is an animated image."
  @spec animated?(t() | map() | integer() | nil) :: boolean()
  def animated?(attachment), do: has_flag?(attachment, :animated)

  # ── Edit requests ──

  @doc """
  Builds the entry that keeps this attachment on a message being edited.

  An `attachments` array that omits an attachment deletes it, so every attachment the
  message should still have needs one of these. Accepts a `t:t/0`, a raw attachment map, or
  a bare id.

  ## Options

  Both are optional; leaving one out keeps the attachment's current value rather than
  clearing it. Discord accepts no other field for an attachment that already exists.

    * `:description` - new alt text (max #{@max_description_length} characters)
    * `:is_spoiler` - blur it until clicked, or stop blurring it

  ## Examples

      iex> EDA.Attachment.keep(%EDA.Attachment{id: "123", filename: "a.png"})
      %{id: "123"}

      iex> EDA.Attachment.keep("123", is_spoiler: true, description: "A cat")
      %{id: "123", description: "A cat", is_spoiler: true}
  """
  @spec keep(t() | map() | String.t() | integer(), keyword()) :: map()
  def keep(attachment, opts \\ [])

  def keep(%__MODULE__{id: id}, opts), do: keep(id, opts)
  def keep(%{"id" => id}, opts), do: keep(id, opts)

  def keep(id, opts) when is_binary(id) or is_integer(id) do
    %{id: id}
    |> put_description(Keyword.get(opts, :description))
    |> put_spoiler(Keyword.get(opts, :is_spoiler))
  end

  defp put_description(entry, nil), do: entry

  defp put_description(entry, description) when is_binary(description) do
    if String.length(description) > @max_description_length do
      raise ArgumentError,
            "attachment description exceeds #{@max_description_length} characters"
    end

    Map.put(entry, :description, description)
  end

  defp put_description(_entry, other) do
    raise ArgumentError, "attachment description must be a string, got: #{inspect(other)}"
  end

  defp put_spoiler(entry, nil), do: entry

  defp put_spoiler(entry, spoiler) when is_boolean(spoiler),
    do: Map.put(entry, :is_spoiler, spoiler)

  defp put_spoiler(_entry, other) do
    raise ArgumentError, "attachment :is_spoiler must be a boolean, got: #{inspect(other)}"
  end

  defp parse_users(nil), do: nil
  defp parse_users(list) when is_list(list), do: Enum.map(list, &EDA.User.from_raw/1)

  @doc """
  Whether the attachment is an image, from its content type, or its extension when Discord
  sent none.

      iex> EDA.Attachment.image?(%EDA.Attachment{filename: "cat.PNG"})
      true
  """
  @spec image?(t()) :: boolean()
  def image?(%__MODULE__{} = attachment), do: kind(attachment) == "image"

  @doc "Whether the attachment is a video. See `image?/1`."
  @spec video?(t()) :: boolean()
  def video?(%__MODULE__{} = attachment), do: kind(attachment) == "video"

  @doc "Whether the attachment is audio, a voice message included. See `image?/1`."
  @spec audio?(t()) :: boolean()
  def audio?(%__MODULE__{} = attachment), do: kind(attachment) == "audio"

  @doc """
  The file's extension, lowercased and without the dot, or `nil`.

      iex> EDA.Attachment.extension(%EDA.Attachment{filename: "Report.Final.PDF"})
      "pdf"
  """
  @spec extension(t()) :: String.t() | nil
  def extension(%__MODULE__{filename: name}) when is_binary(name) do
    case Path.extname(name) do
      "" -> nil
      ext -> ext |> String.trim_leading(".") |> String.downcase()
    end
  end

  def extension(%__MODULE__{}), do: nil

  @kinds %{
    "png" => "image",
    "jpg" => "image",
    "jpeg" => "image",
    "gif" => "image",
    "webp" => "image",
    "avif" => "image",
    "mp4" => "video",
    "webm" => "video",
    "mov" => "video",
    "mp3" => "audio",
    "ogg" => "audio",
    "wav" => "audio",
    "flac" => "audio",
    "m4a" => "audio"
  }

  defp kind(%__MODULE__{content_type: type}) when is_binary(type),
    do: type |> String.split("/") |> hd()

  defp kind(%__MODULE__{} = attachment), do: Map.get(@kinds, extension(attachment))
end
