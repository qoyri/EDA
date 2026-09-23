defmodule EDA.AutoMod.ActionMetadata do
  @moduledoc """
  Metadata for an Auto Moderation action.

  Fields vary by action type:
  - `block_message` → `:custom_message`
  - `send_alert` → `:channel_id`
  - `timeout` → `:duration_seconds`
  """

  use EDA.Event.Access

  defstruct [:channel_id, :duration_seconds, :custom_message]

  @type t :: %__MODULE__{
          channel_id: String.t() | nil,
          duration_seconds: integer() | nil,
          custom_message: String.t() | nil
        }

  @doc "Converts a raw Discord action metadata map into this struct."
  @spec from_raw(map() | nil) :: t() | nil
  def from_raw(nil), do: nil

  def from_raw(%__MODULE__{} = parsed), do: parsed

  def from_raw(raw) when is_map(raw) do
    %__MODULE__{
      channel_id: :maps.get("channel_id", raw, nil),
      duration_seconds: :maps.get("duration_seconds", raw, nil),
      custom_message: :maps.get("custom_message", raw, nil)
    }
  end

  @doc "Converts this struct to a map for API serialization, dropping nil values."
  @spec to_map(t()) :: map()
  def to_map(%__MODULE__{} = meta) do
    %{}
    |> maybe_put(:channel_id, meta.channel_id)
    |> maybe_put(:duration_seconds, meta.duration_seconds)
    |> maybe_put(:custom_message, meta.custom_message)
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
