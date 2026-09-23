defmodule EDA.AutoMod.TriggerMetadata do
  @moduledoc """
  Metadata for an Auto Moderation rule trigger.

  Fields vary by trigger type:
  - `keyword` / `member_profile` → `:keyword_filter`, `:regex_patterns`, `:allow_list`
  - `keyword_preset` → `:presets`, `:allow_list`
  - `mention_spam` → `:mention_total_limit`, `:mention_raid_protection_enabled`
  """

  use EDA.Event.Access

  @presets %{1 => :profanity, 2 => :sexual_content, 3 => :slurs}

  defstruct [
    :keyword_filter,
    :regex_patterns,
    :presets,
    :allow_list,
    :mention_total_limit,
    :mention_raid_protection_enabled
  ]

  @type t :: %__MODULE__{
          keyword_filter: [String.t()] | nil,
          regex_patterns: [String.t()] | nil,
          presets: [:profanity | :sexual_content | :slurs | integer()] | nil,
          allow_list: [String.t()] | nil,
          mention_total_limit: integer() | nil,
          mention_raid_protection_enabled: boolean() | nil
        }

  @doc "Converts a raw Discord trigger metadata map into this struct."
  @spec from_raw(map() | nil) :: t() | nil
  def from_raw(nil), do: nil

  def from_raw(raw) when is_map(raw) do
    %__MODULE__{
      keyword_filter: raw["keyword_filter"],
      regex_patterns: raw["regex_patterns"],
      presets: parse_presets(raw["presets"]),
      allow_list: raw["allow_list"],
      mention_total_limit: raw["mention_total_limit"],
      mention_raid_protection_enabled: raw["mention_raid_protection_enabled"]
    }
  end

  @doc "Converts this struct to a map for API serialization, dropping nil values."
  @spec to_map(t()) :: map()
  def to_map(%__MODULE__{} = meta) do
    %{}
    |> maybe_put(:keyword_filter, meta.keyword_filter)
    |> maybe_put(:regex_patterns, meta.regex_patterns)
    |> maybe_put(:presets, meta.presets && Enum.map(meta.presets, &preset_value/1))
    |> maybe_put(:allow_list, meta.allow_list)
    |> maybe_put(:mention_total_limit, meta.mention_total_limit)
    |> maybe_put(:mention_raid_protection_enabled, meta.mention_raid_protection_enabled)
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  @doc """
  The integer Discord uses for a keyword preset, from its atom (`:profanity`, `:sexual_content`,
  `:slurs`) or the integer itself.
  """
  @spec preset_value(atom() | integer()) :: integer()
  def preset_value(value), do: EDA.Enum.value!(@presets, value, "AutoMod keyword preset")

  defp parse_presets(nil), do: nil
  defp parse_presets(list) when is_list(list), do: Enum.map(list, &EDA.Enum.name(@presets, &1))
end
