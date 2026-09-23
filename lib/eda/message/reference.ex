defmodule EDA.Message.Reference do
  @moduledoc """
  What a message points to: the message it replies to (`type: :default`), or the one it
  forwards (`type: :forward`), whose content is then in the message's `message_snapshots`.

  It encodes to JSON as Discord takes it, so it can be sent as a message's `message_reference`.
  """

  use EDA.Event.Access

  defstruct [:type, :message_id, :channel_id, :guild_id, :fail_if_not_exists]

  @type t :: %__MODULE__{
          type: :default | :forward | integer() | nil,
          message_id: String.t() | nil,
          channel_id: String.t() | nil,
          guild_id: String.t() | nil,
          fail_if_not_exists: boolean() | nil
        }

  @types %{0 => :default, 1 => :forward}

  @doc false
  @spec from_raw(map() | nil) :: t() | nil
  def from_raw(nil), do: nil

  def from_raw(%__MODULE__{} = parsed), do: parsed

  def from_raw(raw) when is_map(raw) do
    %__MODULE__{
      type: EDA.Enum.name(@types, :maps.get("type", raw, nil) || 0),
      message_id: :maps.get("message_id", raw, nil),
      channel_id: :maps.get("channel_id", raw, nil),
      guild_id: :maps.get("guild_id", raw, nil),
      fail_if_not_exists: :maps.get("fail_if_not_exists", raw, nil)
    }
  end

  @doc false
  @spec to_raw(t()) :: map()
  def to_raw(%__MODULE__{} = reference) do
    reference
    |> Map.from_struct()
    |> Map.update!(:type, &(&1 && EDA.Enum.value!(@types, &1, "message reference type")))
    |> Map.reject(fn {_k, v} -> is_nil(v) end)
  end
end

defimpl Jason.Encoder, for: EDA.Message.Reference do
  def encode(reference, opts),
    do: reference |> EDA.Message.Reference.to_raw() |> Jason.Encode.map(opts)
end
