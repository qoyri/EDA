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
end
