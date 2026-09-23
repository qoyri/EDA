defmodule EDA.Component.SelectMenu do
  @moduledoc """
  A select menu: `type` says which, `:string_select` with its `options`, or `:user_select`,
  `:role_select`, `:mentionable_select` or `:channel_select`, which Discord fills itself.

  `default_values` are `{:user, id}`, `{:role, id}` or `{:channel, id}` tuples, the shape
  `EDA.Component.mentionable_select/2` takes them in. In a component interaction or a modal
  submission, `values` are the choices made.
  """

  use EDA.Event.Access

  alias EDA.Component

  defstruct [
    :type,
    :id,
    :custom_id,
    :options,
    :channel_types,
    :placeholder,
    :default_values,
    :min_values,
    :max_values,
    :required,
    :disabled,
    :values
  ]

  @type t :: %__MODULE__{
          type: EDA.Component.type(),
          id: integer() | nil,
          custom_id: String.t() | nil,
          options: [EDA.Component.SelectOption.t()] | nil,
          channel_types: [EDA.Channel.channel_type()] | nil,
          placeholder: String.t() | nil,
          default_values: [{atom() | String.t(), String.t()}] | nil,
          min_values: non_neg_integer() | nil,
          max_values: non_neg_integer() | nil,
          required: boolean() | nil,
          disabled: boolean(),
          values: [String.t()] | nil
        }

  @doc false
  @spec from_raw(map()) :: t()
  def from_raw(%__MODULE__{} = parsed), do: parsed

  def from_raw(raw) when is_map(raw) do
    %__MODULE__{
      type: Component.type_name(:maps.get("type", raw, nil)),
      id: :maps.get("id", raw, nil),
      custom_id: :maps.get("custom_id", raw, nil),
      options: Component.parse_options(:maps.get("options", raw, nil)),
      channel_types: parse_channel_types(:maps.get("channel_types", raw, nil)),
      placeholder: :maps.get("placeholder", raw, nil),
      default_values: parse_default_values(:maps.get("default_values", raw, nil)),
      min_values: :maps.get("min_values", raw, nil),
      max_values: :maps.get("max_values", raw, nil),
      required: :maps.get("required", raw, nil),
      disabled: :maps.get("disabled", raw, nil) == true,
      values: :maps.get("values", raw, nil)
    }
  end

  defp parse_channel_types(nil), do: nil
  defp parse_channel_types(list), do: Enum.map(list, &EDA.Channel.type_name/1)

  @default_value_types %{"user" => :user, "role" => :role, "channel" => :channel}

  defp parse_default_values(nil), do: nil

  defp parse_default_values(list) do
    Enum.map(list, fn v -> {Map.get(@default_value_types, v["type"], v["type"]), v["id"]} end)
  end
end

defimpl Jason.Encoder, for: EDA.Component.SelectMenu do
  def encode(component, opts), do: component |> EDA.Component.to_raw() |> Jason.Encode.map(opts)
end
