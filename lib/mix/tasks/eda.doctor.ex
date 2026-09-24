defmodule Mix.Tasks.Eda.Doctor do
  @shortdoc "Finds code that EDA's structs make wrong without an error"

  @moduledoc """
  Finds the code that compiles, passes its tests, and misbehaves since EDA returns structs.

      mix eda.doctor              # scans lib/ and test/
      mix eda.doctor lib/bot      # scans the given files or directories
      mix eda.doctor --strict     # exits with status 1 when anything is found

  Since 0.5, events, caches and entity functions return structs whose enumerations are atoms and
  whose dates are `DateTime`s. `x["field"]` still reads a struct, which is why most code keeps
  working. What breaks does so silently:

  - **`Map.get(x, "field")`**, `Map.fetch/2`, `Map.has_key?/2`, `Map.put/3`, `Map.update/4` with
    a string key: a struct has atom keys, so reads give `nil` or `:error` and writes add a key the
    struct does not know.
  - **`%{"field" => value}` patterns**: they no longer match a struct, so the clause is skipped.
  - **An enumeration compared to Discord's integer**: `channel.type == 0`, `type in [20, 22]`,
    `%{type: 2}`. The field holds `:guild_text` now, so the comparison is always false.
  - **A presence status compared to a string**: `status == "online"`; it is `:online`.
  - **`DateTime.from_iso8601/1` on a date EDA parses**: it is a `DateTime` already.

  Each finding names the file, the line and what to write instead. The search is textual, so it
  also flags a map that really is Discord's raw payload, from `EDA.API.*` for instance: those
  keep string keys and integers, and are right as they are. Add `# eda-doctor: ignore` to a line
  to silence it.
  """

  use Mix.Task

  @ignore_marker "eda-doctor: ignore"

  # Fields holding one of Discord's integer enumerations, an atom in EDA's structs.
  @enum_fields ~w(type style premium_type verification_level default_message_notifications
    explicit_content_filter mfa_level nsfw_level premium_tier privacy_level entity_type status
    trigger_type event_type action_type layout_type video_quality_mode mode preset spacing
    format_type sort_order default_sort_order default_forum_layout target_type)

  # Fields holding a date, a DateTime in EDA's structs.
  @date_fields ~w(timestamp edited_timestamp joined_at premium_since communication_disabled_until
    created_at expires_at archive_timestamp create_timestamp last_pin_timestamp
    scheduled_start_time scheduled_end_time starts_at ends_at synced_at updated_at
    request_to_speak_timestamp)

  @impl Mix.Task
  def run(args) do
    {opts, paths} = OptionParser.parse!(args, strict: [strict: :boolean])
    paths = if paths == [], do: ["lib", "test"], else: paths

    fields = struct_fields()

    findings =
      paths
      |> Enum.flat_map(&source_files/1)
      |> Enum.flat_map(fn file -> scan(File.read!(file), file, fields) end)

    Enum.each(findings, &print/1)
    summary(findings)

    if opts[:strict] && findings != [], do: exit({:shutdown, 1})
  end

  @doc false
  # The findings in one source: [{file, line, snippet, message}].
  @spec scan(String.t(), String.t(), MapSet.t(String.t())) :: [tuple()]
  def scan(source, file, fields) do
    source
    |> String.split("\n")
    |> Enum.with_index(1)
    |> Enum.reject(fn {line, _} -> skip?(line) end)
    |> Enum.flat_map(fn {line, number} ->
      for message <- line_findings(line, fields), do: {file, number, String.trim(line), message}
    end)
  end

  defp skip?(line) do
    trimmed = String.trim_leading(line)
    String.starts_with?(trimmed, "#") or String.contains?(line, @ignore_marker)
  end

  defp line_findings(line, fields) do
    Enum.concat([
      map_function_findings(line, fields),
      string_pattern_findings(line, fields),
      enum_findings(line),
      status_findings(line),
      date_findings(line)
    ])
  end

  @map_call ~r/\bMap\.(get|fetch!?|has_key\?|put|update!?|pop|delete)\([^,()]+,\s*"([a-z_]+)"/

  defp map_function_findings(line, fields) do
    for [_, fun, key] <- Regex.scan(@map_call, line), MapSet.member?(fields, key) do
      "Map.#{fun} with the string key \"#{key}\" does not see an EDA struct's field: " <>
        "use x.#{key}, or x[\"#{key}\"], which still reads a struct"
    end
  end

  @string_pattern ~r/%\{[^}]*"([a-z_]+)"\s*=>/

  # Only a pattern fails silently; a map being built is sent as written.
  @match_context ~r/^\s*(?:defp?|defmacrop?)\b|->|\}\s*=[^=~>]/

  defp match_context?(line), do: Regex.match?(@match_context, line)

  defp string_pattern_findings(line, fields) do
    scanned = if match_context?(line), do: Regex.scan(@string_pattern, line), else: []

    for [_, key] <- scanned,
        MapSet.member?(fields, key),
        uniq: true do
      "%{\"#{key}\" => ...} does not match an EDA struct: match %{#{key}: ...} " <>
        "(or leave it, if this is a raw payload from EDA.API)"
    end
  end

  @enum_alternation Enum.join(@enum_fields, "|")
  @enum_compare Regex.compile!(
                  "(?:\\.|\\[\"|\\[:)(#{@enum_alternation})(?:\"\\]|\\])?\\s*(?:===?|!==?)\\s*-?\\d+\\b"
                )
  @enum_in Regex.compile!(
             "(?:\\.|\\[\"|\\[:)(#{@enum_alternation})(?:\"\\]|\\])?\\s+(?:not\\s+)?in\\s+\\[\\s*-?\\d"
           )
  @enum_pattern Regex.compile!(
                  "%(?:[A-Z][\\w.]*)?\\{[^}]*\\b(#{@enum_alternation}):\\s*-?\\d+\\b"
                )

  defp enum_findings(line) do
    regexes = [@enum_compare, @enum_in] ++ if(match_context?(line), do: [@enum_pattern], else: [])

    for regex <- regexes,
        [_, field] <- Regex.scan(regex, line),
        uniq: true do
      "`#{field}` is an atom in EDA's structs (:guild_text, :reply...), so comparing it to an " <>
        "integer is always false: compare to the atom (a value EDA does not know yet stays an integer)"
    end
  end

  @status_compare ~r/\bstatus\b[^=\n]*?(?:===?|!==?)\s*"(online|idle|dnd|offline|invisible)"/

  defp status_findings(line) do
    for [_, status] <- Regex.scan(@status_compare, line), uniq: true do
      "a presence status is an atom: compare to :#{status}, not \"#{status}\""
    end
  end

  @date_alternation Enum.join(@date_fields, "|")
  @date_parse Regex.compile!(
                "DateTime\\.from_iso8601\\([^)]*(?:\\.|\\[\"|\\[:)(#{@date_alternation})\\b"
              )

  defp date_findings(line) do
    for [_, field] <- Regex.scan(@date_parse, line), uniq: true do
      "`#{field}` is a DateTime already in EDA's structs: DateTime.from_iso8601/1 fails on it " <>
        "(EDA.Timestamp.parse/1 takes either)"
    end
  end

  defp source_files(path) do
    cond do
      File.regular?(path) -> [path]
      File.dir?(path) -> Path.wildcard(Path.join(path, "**/*.{ex,exs}"))
      true -> []
    end
  end

  # The field names of every struct EDA defines.
  defp struct_fields do
    Mix.Task.run("loadpaths")
    Application.load(:eda)
    {:ok, modules} = :application.get_key(:eda, :modules)

    for module <- modules,
        Code.ensure_loaded?(module),
        function_exported?(module, :__struct__, 0),
        field <- Map.keys(module.__struct__()),
        field != :__struct__,
        into: MapSet.new(),
        do: Atom.to_string(field)
  end

  defp print({file, line, snippet, message}) do
    Mix.shell().info([:bright, "#{file}:#{line}", :reset, ": #{message}\n    #{snippet}\n"])
  end

  defp summary([]), do: Mix.shell().info("eda.doctor: nothing found.")

  defp summary(findings) do
    files = findings |> Enum.map(&elem(&1, 0)) |> Enum.uniq() |> length()

    Mix.shell().info(
      "eda.doctor: #{length(findings)} finding(s) in #{files} file(s). The search is textual: " <>
        "a raw payload from EDA.API keeps string keys and integers, and may be right as it is."
    )
  end
end
