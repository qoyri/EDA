defmodule EDA.ScheduledEvent.EntityMetadata do
  @moduledoc """
  Where an `:external` scheduled event takes place, in `location`. It encodes as Discord takes
  it, so it can be sent when creating or editing the event.
  """

  use EDA.Event.Access

  defstruct [:location]

  @type t :: %__MODULE__{location: String.t() | nil}

  @doc false
  @spec from_raw(map() | nil) :: t() | nil
  def from_raw(nil), do: nil
  def from_raw(raw) when is_map(raw), do: %__MODULE__{location: raw["location"]}
end

defimpl Jason.Encoder, for: EDA.ScheduledEvent.EntityMetadata do
  def encode(metadata, opts), do: Jason.Encode.map(%{location: metadata.location}, opts)
end
