defmodule EDA.Onboarding.Prompt do
  @moduledoc "A question in a guild's onboarding. Build one with `EDA.Onboarding.prompt/3`."

  use EDA.Event.Access

  alias EDA.Onboarding.Option

  defstruct [
    :id,
    :title,
    type: :multiple_choice,
    options: [],
    single_select: false,
    required: false,
    in_onboarding: true
  ]

  @type t :: %__MODULE__{
          id: String.t() | nil,
          title: String.t() | nil,
          type: :multiple_choice | :dropdown | integer(),
          options: [Option.t()],
          single_select: boolean(),
          required: boolean(),
          in_onboarding: boolean()
        }

  @types %{0 => :multiple_choice, 1 => :dropdown}

  @doc "Converts a raw prompt into this struct."
  @spec from_raw(map()) :: t()
  def from_raw(%__MODULE__{} = parsed), do: parsed

  def from_raw(raw) when is_map(raw) do
    %__MODULE__{
      id: :maps.get("id", raw, nil),
      title: :maps.get("title", raw, nil),
      type: Map.get(@types, :maps.get("type", raw, nil), :maps.get("type", raw, nil)),
      options: Enum.map(:maps.get("options", raw, nil) || [], &Option.from_raw/1),
      single_select: :maps.get("single_select", raw, nil) || false,
      required: :maps.get("required", raw, nil) || false,
      in_onboarding: Map.get(raw, "in_onboarding", true)
    }
  end

  @doc false
  def to_payload(%__MODULE__{} = prompt) do
    %{
      id: prompt.id,
      title: prompt.title,
      type: type_value!(prompt.type),
      options: Enum.map(prompt.options, &Option.to_payload/1),
      single_select: prompt.single_select,
      required: prompt.required,
      in_onboarding: prompt.in_onboarding
    }
  end

  defp type_value!(nil), do: nil
  defp type_value!(:multiple_choice), do: 0
  defp type_value!(:dropdown), do: 1
  defp type_value!(n) when n in [0, 1], do: n

  defp type_value!(other),
    do:
      raise(ArgumentError, "prompt type is :multiple_choice or :dropdown, got #{inspect(other)}")
end
