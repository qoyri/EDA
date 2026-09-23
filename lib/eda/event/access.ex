defmodule EDA.Event.Access do
  @moduledoc false
  # Lets every EDA struct be read as `x.field`, `x[:field]` and `x["field"]`.
  #
  # The string form used to go through `String.to_existing_atom/1` on every read — the slowest
  # of the three, measured at about ten times a dot access. The clauses below are generated from
  # the struct's own fields once it is defined, so a string key is matched like any other
  # literal, an unknown one answers `:error` without touching the atom table, and neither
  # `put_in/3` nor `pop_in/2` can add a key the struct does not have or remove one it has.

  defmacro __using__(_opts) do
    quote do
      @behaviour Access
      @before_compile EDA.Event.Access
    end
  end

  defmacro __before_compile__(env) do
    fields =
      env.module
      |> Module.get_attribute(:__struct__)
      |> Map.keys()
      |> Enum.reject(&(&1 == :__struct__))

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
          defp __access_key__(unquote(name)), do: unquote(field)
          defp __access_key__(unquote(field)), do: unquote(field)
        end
      end

    quote do
      @impl Access
      def fetch(struct, key) when is_atom(key), do: Map.fetch(struct, key)
      unquote_splicing(fetch_clauses)
      def fetch(_struct, key) when is_binary(key), do: :error

      @impl Access
      def get_and_update(struct, key, fun) do
        case __access_key__(key) do
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
        case __access_key__(key) do
          nil -> {nil, struct}
          field -> {Map.fetch!(struct, field), Map.put(struct, field, nil)}
        end
      end

      unquote_splicing(key_clauses)
      defp __access_key__(_key), do: nil
    end
  end
end
