defmodule EDA.Member.Flags do
  @moduledoc """
  What a member has done in a guild, as the bits of their `flags`.

  Discord sends an integer; this turns it into atoms and back, like `EDA.User.Flags` does for
  profile badges. `EDA.Member.flags/1` reads it straight off a member.

  Only `:bypasses_verification` can be written back, through `EDA.Member.modify/4`; Discord
  refuses to set any of the others.

      iex> EDA.Member.Flags.to_list(1 ||| 1 <<< 1)
      [:did_rejoin, :completed_onboarding]

  `:automod_quarantined_username` and `:automod_quarantined_guild_tag` are how automod says it
  is hiding a member's name or server tag, which is otherwise invisible to a bot.
  """

  import Bitwise

  @flags %{
    did_rejoin: 1 <<< 0,
    completed_onboarding: 1 <<< 1,
    bypasses_verification: 1 <<< 2,
    started_onboarding: 1 <<< 3,
    is_guest: 1 <<< 4,
    started_home_actions: 1 <<< 5,
    completed_home_actions: 1 <<< 6,
    automod_quarantined_username: 1 <<< 7,
    dm_settings_upsell_acknowledged: 1 <<< 9,
    automod_quarantined_guild_tag: 1 <<< 10
  }

  @bit_to_flag Map.new(@flags, fn {name, bit} -> {bit, name} end)

  @type flag ::
          :did_rejoin
          | :completed_onboarding
          | :bypasses_verification
          | :started_onboarding
          | :is_guest
          | :started_home_actions
          | :completed_home_actions
          | :automod_quarantined_username
          | :dm_settings_upsell_acknowledged
          | :automod_quarantined_guild_tag

  @doc """
  The bit of a flag.

      iex> EDA.Member.Flags.to_bit(:bypasses_verification)
      4
  """
  @spec to_bit(flag()) :: pos_integer()
  def to_bit(flag) when is_map_key(@flags, flag), do: Map.fetch!(@flags, flag)

  @doc """
  The flag of a bit, or `:error` for one Discord does not document.

      iex> EDA.Member.Flags.from_bit(1)
      {:ok, :did_rejoin}

      iex> EDA.Member.Flags.from_bit(1 <<< 8)
      :error
  """
  @spec from_bit(integer()) :: {:ok, flag()} | :error
  def from_bit(bit), do: Map.fetch(@bit_to_flag, bit)

  @doc """
  The combined bitset of a list of flags.

      iex> EDA.Member.Flags.to_bitset([:did_rejoin, :is_guest])
      17
  """
  @spec to_bitset([flag()]) :: non_neg_integer()
  def to_bitset(flags) when is_list(flags),
    do: Enum.reduce(flags, 0, fn flag, acc -> acc ||| to_bit(flag) end)

  @doc """
  The flags set in a bitset, lowest bit first. Undocumented bits are skipped, and `nil` gives
  `[]`.

      iex> EDA.Member.Flags.to_list(4)
      [:bypasses_verification]

      iex> EDA.Member.Flags.to_list(nil)
      []
  """
  @spec to_list(integer() | nil) :: [flag()]
  def to_list(nil), do: []

  def to_list(bitset) when is_integer(bitset) do
    @flags
    |> Enum.filter(fn {_name, bit} -> (bitset &&& bit) != 0 end)
    |> Enum.sort_by(fn {_name, bit} -> bit end)
    |> Enum.map(fn {name, _bit} -> name end)
  end

  @doc """
  Whether a bitset carries a flag.

      iex> EDA.Member.Flags.has?(4, :bypasses_verification)
      true

      iex> EDA.Member.Flags.has?(nil, :is_guest)
      false
  """
  @spec has?(integer() | nil, flag()) :: boolean()
  def has?(nil, _flag), do: false

  def has?(bitset, flag) when is_integer(bitset) and is_map_key(@flags, flag),
    do: (bitset &&& Map.fetch!(@flags, flag)) != 0
end
