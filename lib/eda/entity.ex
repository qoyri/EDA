defmodule EDA.Entity do
  @moduledoc """
  Shared behaviour for EDA entity modules that support fetch, modify, and changeset operations.

  Injects `changeset/1`, `change/3`, and a private `parse_response/1` helper
  that converts raw API maps into typed entity structs via `from_raw/1`.

  ## Usage

      defmodule EDA.Guild do
        use EDA.Entity

        # Adds: changeset/1, change/3, parse_response/1 (private)
      end
  """

  defmacro __using__(_opts) do
    quote do
      alias EDA.Entity.Changeset

      @doc "Creates a changeset for batching mutations to this entity."
      @spec changeset(t()) :: Changeset.t()
      def changeset(%__MODULE__{} = entity), do: Changeset.new(entity, __MODULE__)

      @doc "Adds a change to an existing changeset for this entity."
      @spec change(Changeset.t(), atom(), term()) :: Changeset.t()
      def change(%Changeset{module: __MODULE__} = cs, key, value),
        do: Changeset.put(cs, key, value)

      # Generic across every entity: an API function may return {:ok, map} (200),
      # {:ok, nil} (204 — see EDA.HTTP.Client.handle_response/2) or a bare :ok.
      # No single module exercises all four clauses, so Dialyzer sees the unused
      # ones as dead per module. Scoped to this function only.
      @dialyzer {:nowarn_function, parse_response: 1}

      @doc false
      defp parse_response({:ok, raw}) when is_map(raw), do: {:ok, from_raw(raw)}
      defp parse_response({:ok, nil}), do: :ok
      defp parse_response({:error, _} = err), do: err
      defp parse_response(:ok), do: :ok
    end
  end

  @doc """
  Applies a partial update from Discord to an entity: the fields whose key is in `raw` take the
  parsed value, the others keep theirs. A key present with a `nil` value clears the field; a key
  absent leaves it alone, which is how Discord's partial updates work.

  The cache uses it to apply `GUILD_MEMBER_UPDATE`, `CHANNEL_UPDATE` and the other updates to
  the structs it holds.

      iex> member = %EDA.Member{nick: "Annie", roles: ["1"]}
      iex> EDA.Entity.patch(member, %{"nick" => nil})
      %EDA.Member{nick: nil, roles: ["1"]}
  """
  @spec patch(struct(), map()) :: struct()
  def patch(%mod{} = entity, raw) when is_map(raw) do
    if function_exported?(mod, :patch, 2),
      do: mod.patch(entity, raw),
      else: patch_fields(entity, raw)
  end

  @doc false
  # The generic patch: a field takes the parsed value when its name is a key of `raw`.
  def patch_fields(%mod{} = entity, raw) do
    parsed = mod.from_raw(raw)

    entity
    |> Map.from_struct()
    |> Map.keys()
    |> Enum.reduce(entity, fn field, acc ->
      if Map.has_key?(raw, Atom.to_string(field)),
        do: Map.put(acc, field, Map.fetch!(parsed, field)),
        else: acc
    end)
  end
end
