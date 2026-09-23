defmodule EDA.User.Flags do
  @moduledoc """
  The badges on a user's profile, as the bits of `public_flags`.

  Discord sends an integer; this turns it into atoms and back, like `EDA.Permission` does for
  permissions. `EDA.User.badges/1` reads it straight off a user.

      iex> EDA.User.Flags.to_list(1 <<< 0 ||| 1 <<< 22)
      [:staff, :active_developer]

  `:active_developer` is not in Discord's table of user flags, but the badge exists and the bit
  is stable; a bot that ignores it misreads a common profile. Bits Discord does not document at
  all are skipped by `to_list/1` rather than guessed at.

  Flags with no badge of their own are here because Discord documents them: `:team_pseudo_user`
  marks the pseudo-user of a team, `:verified_bot` and `:bot_http_interactions` describe a bot,
  and `:hypesquad` is the events member flag, distinct from the three house flags.
  """

  import Bitwise

  @flags %{
    staff: 1 <<< 0,
    partner: 1 <<< 1,
    hypesquad: 1 <<< 2,
    bug_hunter_level_1: 1 <<< 3,
    hypesquad_online_house_1: 1 <<< 6,
    hypesquad_online_house_2: 1 <<< 7,
    hypesquad_online_house_3: 1 <<< 8,
    premium_early_supporter: 1 <<< 9,
    team_pseudo_user: 1 <<< 10,
    bug_hunter_level_2: 1 <<< 14,
    verified_bot: 1 <<< 16,
    verified_developer: 1 <<< 17,
    certified_moderator: 1 <<< 18,
    bot_http_interactions: 1 <<< 19,
    active_developer: 1 <<< 22
  }

  @bit_to_flag Map.new(@flags, fn {name, bit} -> {bit, name} end)

  @type flag ::
          :staff
          | :partner
          | :hypesquad
          | :bug_hunter_level_1
          | :hypesquad_online_house_1
          | :hypesquad_online_house_2
          | :hypesquad_online_house_3
          | :premium_early_supporter
          | :team_pseudo_user
          | :bug_hunter_level_2
          | :verified_bot
          | :verified_developer
          | :certified_moderator
          | :bot_http_interactions
          | :active_developer

  @doc """
  The three HypeSquad houses, in Discord's order: bravery, brilliance, balance.

      iex> EDA.User.Flags.houses()
      [:hypesquad_online_house_1, :hypesquad_online_house_2, :hypesquad_online_house_3]
  """
  @spec houses() :: [flag()]
  def houses,
    do: [:hypesquad_online_house_1, :hypesquad_online_house_2, :hypesquad_online_house_3]

  @doc """
  The bit of a flag.

      iex> EDA.User.Flags.to_bit(:active_developer)
      4194304
  """
  @spec to_bit(flag()) :: pos_integer()
  def to_bit(flag) when is_map_key(@flags, flag), do: Map.fetch!(@flags, flag)

  @doc """
  The flag of a bit, or `:error` for one Discord does not document.

      iex> EDA.User.Flags.from_bit(1)
      {:ok, :staff}

      iex> EDA.User.Flags.from_bit(1 <<< 30)
      :error
  """
  @spec from_bit(integer()) :: {:ok, flag()} | :error
  def from_bit(bit), do: Map.fetch(@bit_to_flag, bit)

  @doc """
  The combined bitset of a list of flags.

      iex> EDA.User.Flags.to_bitset([:staff, :partner])
      3
  """
  @spec to_bitset([flag()]) :: non_neg_integer()
  def to_bitset(flags) when is_list(flags),
    do: Enum.reduce(flags, 0, fn flag, acc -> acc ||| to_bit(flag) end)

  @doc """
  The flags set in a bitset, lowest bit first. Undocumented bits are skipped, and `nil` — a user
  Discord sent without `public_flags` — gives `[]`.

      iex> EDA.User.Flags.to_list(64)
      [:hypesquad_online_house_1]

      iex> EDA.User.Flags.to_list(nil)
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

      iex> EDA.User.Flags.has?(64, :hypesquad_online_house_1)
      true

      iex> EDA.User.Flags.has?(nil, :staff)
      false
  """
  @spec has?(integer() | nil, flag()) :: boolean()
  def has?(nil, _flag), do: false

  def has?(bitset, flag) when is_integer(bitset) and is_map_key(@flags, flag),
    do: (bitset &&& Map.fetch!(@flags, flag)) != 0
end
