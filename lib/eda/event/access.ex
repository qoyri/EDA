defmodule EDA.Event.Access do
  @moduledoc false
  # Lets every EDA struct be read as `x.field`, `x[:field]` and `x["field"]`.
  #
  # The string form used to go through `String.to_existing_atom/1` on every read — the slowest
  # of the three, measured at about ten times a dot access. The clauses below are generated from
  # the struct's own fields once it is defined, so a string key is matched like any other
  # literal, an unknown one answers `:error` without touching the atom table, and neither
  # `put_in/3` nor `pop_in/2` can add a key the struct does not have or remove one it has.
  #
  # The fields are read from the definition of `__struct__/0` (`Module.get_definition/2`): the
  # `@__struct__` attribute this used to read is gone at this point from Elixir 1.20 on, which
  # made EDA fail to compile there. Should that definition ever take another shape, the generic
  # clauses at the end still answer correctly, only without the speed-up.

  defmacro __using__(_opts) do
    quote do
      @behaviour Access
      @before_compile EDA.Event.Access
    end
  end

  defmacro __before_compile__(env) do
    fields = struct_fields(env.module)

    fetch_clauses =
      for field <- fields do
        name = Atom.to_string(field)

        quote do
          def fetch(%{unquote(field) => value}, unquote(name)), do: {:ok, value}
        end
      end

    key_clauses =
      for field <- fields do
        name = Atom.to_string(field)

        quote do
          defp __access_key__(_struct, unquote(name)), do: unquote(field)
          defp __access_key__(_struct, unquote(field)), do: unquote(field)
        end
      end

    quote do
      @impl Access
      def fetch(struct, key) when is_atom(key), do: Map.fetch(struct, key)
      unquote_splicing(fetch_clauses)

      def fetch(struct, key) when is_binary(key) do
        case __access_key__(struct, key) do
          nil -> :error
          field -> Map.fetch(struct, field)
        end
      end

      @impl Access
      def get_and_update(struct, key, fun) do
        case __access_key__(struct, key) do
          nil ->
            raise KeyError, key: key, term: struct

          field ->
            case fun.(Map.fetch!(struct, field)) do
              {current, new} -> {current, Map.put(struct, field, new)}
              # Popping a field of a struct cannot remove it: it goes back to nil.
              :pop -> {Map.fetch!(struct, field), Map.put(struct, field, nil)}
            end
        end
      end

      @impl Access
      def pop(struct, key) do
        case __access_key__(struct, key) do
          nil -> {nil, struct}
          field -> {Map.fetch!(struct, field), Map.put(struct, field, nil)}
        end
      end

      unquote_splicing(key_clauses)

      # Reached only when the fields could not be read at compile time, or for a key that is
      # not a field: checked against the struct itself, never creating an atom.
      defp __access_key__(struct, key) when is_atom(key) and key != :__struct__ do
        if Map.has_key?(struct, key), do: key
      end

      defp __access_key__(struct, key) when is_binary(key) do
        atom = String.to_existing_atom(key)
        if atom != :__struct__ and Map.has_key?(struct, atom), do: atom
      rescue
        ArgumentError -> nil
      end

      defp __access_key__(_struct, _key), do: nil
    end
  end

  @doc false
  # The struct's fields, from the body of the `__struct__/0` that `defstruct` defines. An empty
  # list when they cannot be read, which leaves only the generic clauses.
  def struct_fields(module) do
    with {_version, _kind, _meta, [{_clause_meta, [], [], {:%{}, _, pairs}}]} <-
           Module.get_definition(module, {:__struct__, 0}),
         true <- Keyword.keyword?(pairs) do
      pairs |> Keyword.keys() |> Enum.reject(&(&1 == :__struct__))
    else
      _ -> []
    end
  end
end
