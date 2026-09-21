defmodule EDA.HTTP.Multipart do
  @moduledoc """
  Encodes multipart/form-data requests for Discord file uploads.

  Produces iodata bodies with a `payload_json` part and indexed `files[n]` parts.
  Automatically injects the `attachments` array into the JSON payload.

  An `attachments` array already present in the payload is **kept** and the uploaded files
  are appended to it. That is how a message edit retains the attachments it already has:
  Discord deletes any attachment missing from the array, so `EDA.Attachment.keep/2` entries
  go in the payload and the new files are indexed after them.
  """

  @mime_types %{
    ".png" => "image/png",
    ".jpg" => "image/jpeg",
    ".jpeg" => "image/jpeg",
    ".gif" => "image/gif",
    ".webp" => "image/webp",
    ".svg" => "image/svg+xml",
    ".mp3" => "audio/mpeg",
    ".ogg" => "audio/ogg",
    ".wav" => "audio/wav",
    ".flac" => "audio/flac",
    ".mp4" => "video/mp4",
    ".webm" => "video/webm",
    ".mov" => "video/quicktime",
    ".pdf" => "application/pdf",
    ".csv" => "text/csv",
    ".txt" => "text/plain",
    ".json" => "application/json",
    ".zip" => "application/zip",
    ".gz" => "application/gzip",
    ".tar" => "application/x-tar"
  }

  @doc """
  Encodes a JSON payload and files into multipart/form-data.

  Returns `{body_iodata, content_type}` where content_type includes the boundary.

  Each uploaded file gets an entry with `id` matching the file index, `filename`, and
  optional `description`. Entries already in the payload's `attachments` array — the
  attachments an edit is retaining — are preserved and come first.
  """
  @spec encode(map(), [EDA.File.t()]) :: {iodata(), String.t()}
  def encode(json_payload, files) when is_map(json_payload) and is_list(files) do
    boundary = generate_boundary()

    {retained, json_payload} = pop_attachments(json_payload)

    uploaded =
      files
      |> Enum.with_index()
      |> Enum.map(fn {file, index} ->
        %{id: index, filename: EDA.File.effective_name(file)}
        |> maybe_put(:description, file.description)
        |> maybe_put(:is_spoiler, if(file.spoiler, do: true))
      end)

    json_payload = put_attachments(json_payload, retained ++ uploaded)

    body =
      [
        json_part(boundary, json_payload)
        | file_parts(boundary, files)
      ] ++ [closing_boundary(boundary)]

    content_type = "multipart/form-data; boundary=#{boundary}"
    {body, content_type}
  end

  @doc """
  Encodes a payload and **named** file fields into multipart/form-data.

  `encode/2` is for Discord's message attachments, which are always `files[n]` accompanied
  by an `attachments` array. A handful of endpoints instead want a file under a name of its
  own — `target_users_file` on invites — alongside the other params in `payload_json`.

  `fields` is a list of `{field_name, filename, data}`. The payload is omitted when empty,
  since these endpoints accept a file on its own.

  Returns `{body_iodata, content_type}`.
  """
  @spec encode_named(map(), [{String.t(), String.t(), binary()}]) :: {iodata(), String.t()}
  def encode_named(json_payload, fields) when is_map(json_payload) and is_list(fields) do
    boundary = generate_boundary()

    parts =
      if map_size(json_payload) == 0,
        do: [],
        else: [json_part(boundary, json_payload)]

    parts = parts ++ Enum.map(fields, &named_part(boundary, &1))

    {parts ++ [closing_boundary(boundary)], "multipart/form-data; boundary=#{boundary}"}
  end

  @doc """
  Returns the MIME type for a filename based on its extension.

  Falls back to `application/octet-stream` for unknown extensions.
  """
  @spec mime_type(String.t()) :: String.t()
  def mime_type(filename) when is_binary(filename) do
    ext = filename |> Path.extname() |> String.downcase()
    Map.get(@mime_types, ext, "application/octet-stream")
  end

  # -- Parts --

  defp json_part(boundary, payload) do
    [
      "--",
      boundary,
      "\r\n",
      "Content-Disposition: form-data; name=\"payload_json\"\r\n",
      "Content-Type: application/json\r\n",
      "\r\n",
      Jason.encode!(payload),
      "\r\n"
    ]
  end

  defp named_part(boundary, {name, filename, data}) do
    [
      "--",
      boundary,
      "\r\n",
      "Content-Disposition: form-data; name=\"#{escape_filename(name)}\"; " <>
        "filename=\"#{escape_filename(filename)}\"\r\n",
      "Content-Type: #{mime_type(filename)}\r\n",
      "\r\n",
      data,
      "\r\n"
    ]
  end

  defp file_parts(boundary, files) do
    files
    |> Enum.with_index()
    |> Enum.map(fn {file, index} ->
      effective = EDA.File.effective_name(file)
      escaped = escape_filename(effective)
      content_type = mime_type(effective)

      [
        "--",
        boundary,
        "\r\n",
        "Content-Disposition: form-data; name=\"files[#{index}]\"; filename=\"#{escaped}\"\r\n",
        "Content-Type: #{content_type}\r\n",
        "\r\n",
        file.data,
        "\r\n"
      ]
    end)
  end

  defp closing_boundary(boundary) do
    ["--", boundary, "--\r\n"]
  end

  # -- Helpers --

  # Callers build payloads with atom keys, but `encode/2` is reachable with a hand-written
  # map, so accept either spelling and settle on one.
  defp pop_attachments(payload) do
    {atom, payload} = Map.pop(payload, :attachments)
    {string, payload} = Map.pop(payload, "attachments")

    case atom || string do
      nil -> {[], payload}
      list when is_list(list) -> {list, payload}
      other -> raise ArgumentError, "attachments must be a list, got: #{inspect(other)}"
    end
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  # An empty array deletes every attachment on a message being edited, so only send the key
  # when there is something to say.
  defp put_attachments(payload, []), do: payload
  defp put_attachments(payload, attachments), do: Map.put(payload, :attachments, attachments)

  defp generate_boundary do
    :crypto.strong_rand_bytes(16) |> Base.hex_encode32(case: :lower, padding: false)
  end

  @doc """
  Escapes a filename for use in Content-Disposition headers.

  Escapes backslashes, double quotes, and replaces newlines with underscores.
  """
  @spec escape_filename(String.t()) :: String.t()
  def escape_filename(name) do
    name
    |> String.replace("\\", "\\\\")
    |> String.replace("\"", "\\\"")
    |> String.replace(~r/[\r\n]/, "_")
  end
end
