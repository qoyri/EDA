defmodule EDA.ContentScan do
  @moduledoc false
  # What Discord's content scanning says about a piece of media, read from the two layouts it
  # uses: the `flags` of an attachment or an embed (bits 4, 6 and 7, among other flags), and
  # the `content_scan_metadata.flags` of a component's media (bits 0, 1 and 2).

  import Bitwise

  @type category :: :explicit | :gore | :self_harm

  @media [explicit: 1 <<< 4, gore: 1 <<< 6, self_harm: 1 <<< 7]
  @metadata [explicit: 1 <<< 0, gore: 1 <<< 1, self_harm: 1 <<< 2]

  @doc "The categories set in the `flags` of an attachment or an embed."
  @spec media(integer() | nil) :: [category()]
  def media(flags), do: categories(flags, @media)

  @doc "The categories set in the `flags` of a component media's `content_scan_metadata`."
  @spec metadata(integer() | nil) :: [category()]
  def metadata(flags), do: categories(flags, @metadata)

  defp categories(flags, table) when is_integer(flags),
    do: for({name, bit} <- table, (flags &&& bit) != 0, do: name)

  defp categories(_flags, _table), do: []
end
