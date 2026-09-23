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
  # clauses still answer correctly, only without the speed-up.

  defmacro __using__(_opts) do
    quote do
      @behaviour Access
      @before_compile EDA.Event.Access
    end
  end

  defmacro __before_compile__(env) do
    fields = struct_fields(env.module)

    quote do
      @impl Access
      def fetch(struct, key) when is_atom(key), do: Map.fetch(struct, key)
      unquote_splicing(Enum.map(fields, &fetch_clause/1))

      def fetch(struct, key) when is_binary(key),
        do: EDA.Event.Access.fetch_field(struct, __access_key__(struct, key))

      @impl Access
      def get_and_update(struct, key, fun),
        do: EDA.Event.Access.get_and_update_field(struct, key, __access_key__(struct, key), fun)

      @impl Access
      def pop(struct, key), do: EDA.Event.Access.pop_field(struct, __access_key__(struct, key))

      unquote_splicing(Enum.flat_map(fields, &key_clauses/1))
      defp __access_key__(struct, key), do: EDA.Event.Access.runtime_key(struct, key)
    end
  end

  defp fetch_clause(field) do
    quote do
      def fetch(%{unquote(field) => value}, unquote(Atom.to_string(field))), do: {:ok, value}
    end
  end

  defp key_clauses(field) do
    name = Atom.to_string(field)

    [
      quote(do: defp(__access_key__(_struct, unquote(name)), do: unquote(field))),
      quote(do: defp(__access_key__(_struct, unquote(field)), do: unquote(field)))
    ]
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

  # What the generated functions call once the key is resolved to a field, or to nil when it is
  # not one.

  @doc false
  def fetch_field(_struct, nil), do: :error
  def fetch_field(struct, field), do: Map.fetch(struct, field)

  @doc false
  def get_and_update_field(struct, key, nil, _fun), do: raise(KeyError, key: key, term: struct)

  def get_and_update_field(struct, _key, field, fun) do
    case fun.(Map.fetch!(struct, field)) do
      {current, new} -> {current, Map.put(struct, field, new)}
      # Popping a field of a struct cannot remove it: it goes back to nil.
      :pop -> pop_field(struct, field)
    end
  end

  @doc false
  def pop_field(struct, nil), do: {nil, struct}
  def pop_field(struct, field), do: {Map.fetch!(struct, field), Map.put(struct, field, nil)}

  @doc false
  # For a key the generated clauses did not recognise: checked against the struct itself, and a
  # string never creates an atom.
  def runtime_key(struct, key) when is_atom(key) and key != :__struct__ do
    if Map.has_key?(struct, key), do: key
  end

  def runtime_key(struct, key) when is_binary(key) do
    atom = String.to_existing_atom(key)
    if atom != :__struct__ and Map.has_key?(struct, atom), do: atom
  rescue
    ArgumentError -> nil
  end

  def runtime_key(_struct, _key), do: nil
end
