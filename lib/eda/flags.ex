defmodule EDA.Flags do
  @moduledoc false
  # Generates a flags module from a table of Discord's bits:
  #
  #     use EDA.Flags, flags: %{crossposted: 1 <<< 0, ...}
  #
  # gives `to_bit/1`, `from_bit/1`, `to_bitset/1`, `to_list/1`, `has?/2` and the `flag()` type.
  # Every flags module in EDA answers the same calls, like `EDA.Permission`. Names are Discord's,
  # lowercased; bits it does not document are skipped by `to_list/1` rather than guessed at.

  defmacro __using__(opts) do
    flags = Keyword.fetch!(opts, :flags)

    quote bind_quoted: [flags: flags] do
      import Bitwise

      @flags flags
      @bit_to_flag Map.new(@flags, fn {name, bit} -> {bit, name} end)

      @type flag ::
              unquote(
                flags
                |> Map.keys()
                |> Enum.sort()
                |> Enum.reduce(fn name, acc -> {:|, [], [name, acc]} end)
              )

      @doc "The bit of a flag."
      @spec to_bit(flag()) :: pos_integer()
      def to_bit(flag) when is_map_key(@flags, flag), do: Map.fetch!(@flags, flag)

      @doc "The flag of a bit, or `:error` for one Discord does not document."
      @spec from_bit(integer()) :: {:ok, flag()} | :error
      def from_bit(bit), do: Map.fetch(@bit_to_flag, bit)

      @doc "The combined bitset of a list of flags."
      @spec to_bitset([flag()]) :: non_neg_integer()
      def to_bitset(flags) when is_list(flags),
        do: Enum.reduce(flags, 0, fn flag, acc -> acc ||| to_bit(flag) end)

      @doc """
      The flags set in a bitset, lowest bit first. Undocumented bits are skipped, and `nil` gives
      `[]`.
      """
      @spec to_list(integer() | nil) :: [flag()]
      def to_list(nil), do: []

      def to_list(bitset) when is_integer(bitset) do
        @flags
        |> Enum.filter(fn {_name, bit} -> (bitset &&& bit) != 0 end)
        |> Enum.sort_by(fn {_name, bit} -> bit end)
        |> Enum.map(fn {name, _bit} -> name end)
      end

      @doc "Whether a bitset carries a flag; `nil` carries none."
      @spec has?(integer() | nil, flag()) :: boolean()
      def has?(nil, _flag), do: false

      def has?(bitset, flag) when is_integer(bitset) and is_map_key(@flags, flag),
        do: (bitset &&& Map.fetch!(@flags, flag)) != 0
    end
  end
end
