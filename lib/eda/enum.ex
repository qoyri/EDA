defmodule EDA.Enum do
  @moduledoc false
  # How EDA turns Discord's integer enumerations into atoms, and back.
  #
  # The atom is Discord's documented name, lowercased (`GUILD_ANNOUNCEMENT` → `:guild_announcement`).
  # A value Discord adds before EDA knows it stays the integer, so nothing is lost and a bot can
  # still match on it. Going back, an atom or an integer is accepted, so every outgoing call takes
  # either.

  @doc false
  # The atom for a value, or the value itself when it is not in the table; nil stays nil.
  @spec name(%{integer() => atom()}, integer() | nil) :: atom() | integer() | nil
  def name(_table, nil), do: nil
  def name(table, value) when is_integer(value), do: Map.get(table, value, value)
  def name(_table, value), do: value

  @doc false
  # The integer for an atom or an integer; raises on an atom the table does not have, naming what
  # it is and the atoms it knows.
  @spec value!(%{integer() => atom()}, atom() | integer(), String.t()) :: integer()
  def value!(_table, value, _what) when is_integer(value), do: value

  def value!(table, name, what) when is_atom(name) do
    Enum.find_value(table, fn {int, atom} -> if atom == name, do: int end) ||
      raise ArgumentError,
            "unknown #{what} #{inspect(name)}; known: " <>
              (table |> Enum.sort() |> Enum.map_join(", ", fn {_i, a} -> inspect(a) end))
  end
end
