defmodule EDA.NilPathsTest do
  @moduledoc """
  A field EDA parses may be nil, so every way back to Discord's shape must take nil too: each
  `*_value/1` conversion, and each `to_raw/1`, `to_map/1` or `to_payload/1` given a struct whose
  fields are all unset. Swept over every module, so a new conversion is covered without a test
  of its own.
  """

  use ExUnit.Case, async: true

  # Not conversions of a field: a flag to look up, and a role (not a colour) to read.
  @not_field_values [{EDA.App, :flag_value!}, {EDA.Role, :color_value}]

  setup_all do
    {:ok, modules} = :application.get_key(:eda, :modules)
    Enum.each(modules, &Code.ensure_loaded!/1)
    {:ok, modules: modules}
  end

  test "every *_value/1 conversion gives nil for nil", %{modules: modules} do
    conversions =
      for module <- modules,
          {name, 1} <- module.__info__(:functions),
          String.ends_with?(Atom.to_string(name), ["_value", "_value!"]),
          {module, name} not in @not_field_values,
          do: {module, name}

    assert length(conversions) > 15

    for {module, name} <- conversions do
      assert apply(module, name, [nil]) == nil, "#{inspect(module)}.#{name}(nil)"
    end
  end

  test "every encoder takes a struct with nothing set", %{modules: modules} do
    encoders =
      for module <- modules,
          function_exported?(module, :__struct__, 0),
          name <- [:to_raw, :to_map, :to_payload],
          function_exported?(module, name, 1),
          do: {module, name}

    assert length(encoders) > 10

    for {module, name} <- encoders do
      try do
        apply(module, name, [struct(module)])
      rescue
        e -> flunk("#{inspect(module)}.#{name}/1 on an empty struct: #{Exception.message(e)}")
      end
    end
  end
end
