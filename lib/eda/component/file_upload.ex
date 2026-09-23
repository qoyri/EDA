defmodule EDA.Component.FileUpload do
  @moduledoc """
  A file picker in a modal; in a submission, `values` are the ids of the uploaded attachments.
  """

  use EDA.Event.Access

  defstruct [
    :id,
    :custom_id,
    :min_values,
    :max_values,
    :required,
    :values,
    :file_types,
    type: :file_upload
  ]

  @type t :: %__MODULE__{
          type: :file_upload,
          id: integer() | nil,
          custom_id: String.t() | nil,
          min_values: non_neg_integer() | nil,
          max_values: non_neg_integer() | nil,
          required: boolean() | nil,
          values: [String.t()] | nil,
          file_types: [String.t()] | nil
        }

  @doc false
  @spec from_raw(map()) :: t()
  def from_raw(%__MODULE__{} = parsed), do: parsed

  def from_raw(raw) when is_map(raw) do
    %__MODULE__{
      id: :maps.get("id", raw, nil),
      custom_id: :maps.get("custom_id", raw, nil),
      min_values: :maps.get("min_values", raw, nil),
      max_values: :maps.get("max_values", raw, nil),
      required: :maps.get("required", raw, nil),
      values: :maps.get("values", raw, nil),
      file_types: :maps.get("file_types", raw, nil)
    }
  end
end

defimpl Jason.Encoder, for: EDA.Component.FileUpload do
  def encode(component, opts), do: component |> EDA.Component.to_raw() |> Jason.Encode.map(opts)
end
