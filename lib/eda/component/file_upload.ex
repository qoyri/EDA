defmodule EDA.Component.FileUpload do
  @moduledoc """
  A file picker in a modal; in a submission, `values` are the ids of the uploaded attachments.
  """

  use EDA.Event.Access

  defstruct [:id, :custom_id, :min_values, :max_values, :required, :values, type: :file_upload]

  @type t :: %__MODULE__{
          type: :file_upload,
          id: integer() | nil,
          custom_id: String.t() | nil,
          min_values: non_neg_integer() | nil,
          max_values: non_neg_integer() | nil,
          required: boolean() | nil,
          values: [String.t()] | nil
        }

  @doc false
  @spec from_raw(map()) :: t()
  def from_raw(raw) when is_map(raw) do
    %__MODULE__{
      id: raw["id"],
      custom_id: raw["custom_id"],
      min_values: raw["min_values"],
      max_values: raw["max_values"],
      required: raw["required"],
      values: raw["values"]
    }
  end
end

defimpl Jason.Encoder, for: EDA.Component.FileUpload do
  def encode(component, opts), do: component |> EDA.Component.to_raw() |> Jason.Encode.map(opts)
end
