defmodule EDA.Mention do
  @moduledoc """
  Discord mention and timestamp formatting helpers.

  Generates the special syntax Discord uses to render mentions, channels,
  roles, emojis, and timestamps in messages.

  Unlike `EDA.User.mention/1` or `EDA.Role.mention/1` which work on structs,
  these functions accept raw IDs directly — useful when you only have an ID
  string without fetching the full entity.

  ## Examples

      import EDA.Mention

      user("123456")               #=> "<@123456>"
      channel("789")               #=> "<#789>"
      role("456")                  #=> "<@&456>"
      timestamp(1_700_000_000, :R) #=> "<t:1700000000:R>"
  """

  @timestamp_styles %{
    t: "t",
    T: "T",
    d: "d",
    D: "D",
    f: "f",
    F: "F",
    R: "R"
  }

  @doc """
  Formats a user mention.

  ## Examples

      EDA.Mention.user("123456789")  #=> "<@123456789>"
  """
  @spec user(String.t() | integer()) :: String.t()
  def user(id), do: "<@#{id}>"

  @doc """
  Formats a channel mention.

  ## Examples

      EDA.Mention.channel("123456789")  #=> "<#123456789>"
  """
  @spec channel(String.t() | integer()) :: String.t()
  def channel(id), do: "<##{id}>"

  @doc """
  Formats a role mention.

  ## Examples

      EDA.Mention.role("123456789")  #=> "<@&123456789>"
  """
  @spec role(String.t() | integer()) :: String.t()
  def role(id), do: "<@&#{id}>"

  @doc """
  Formats a custom emoji.

  ## Examples

      EDA.Mention.emoji("wave", "123456")         #=> "<:wave:123456>"
      EDA.Mention.emoji("wave", "123456", true)    #=> "<a:wave:123456>"
  """
  @spec emoji(String.t(), String.t() | integer(), boolean()) :: String.t()
  def emoji(name, id, animated \\ false) do
    prefix = if animated, do: "a", else: ""
    "<#{prefix}:#{name}:#{id}>"
  end

  @doc """
  Formats a Unix timestamp for Discord rendering.

  Discord will render the timestamp in the user's local timezone.

  ## Styles

  | Style | Example output | Atom |
  |-------|---------------|------|
  | Short time | 4:20 PM | `:t` |
  | Long time | 4:20:30 PM | `:T` |
  | Short date | 11/14/2023 | `:d` |
  | Long date | November 14, 2023 | `:D` |
  | Short date/time | November 14, 2023 4:20 PM | `:f` |
  | Long date/time | Tuesday, November 14, 2023 4:20 PM | `:F` |
  | Relative | 2 hours ago | `:R` |

  ## Examples

      EDA.Mention.timestamp(1_700_000_000)       #=> "<t:1700000000>"
      EDA.Mention.timestamp(1_700_000_000, :R)   #=> "<t:1700000000:R>"
      EDA.Mention.timestamp(1_700_000_000, :f)   #=> "<t:1700000000:f>"
  """
  @spec timestamp(integer(), atom()) :: String.t()
  def timestamp(unix, style \\ nil)

  def timestamp(unix, nil) when is_integer(unix), do: "<t:#{unix}>"

  def timestamp(unix, style) when is_integer(unix) and is_map_key(@timestamp_styles, style) do
    "<t:#{unix}:#{@timestamp_styles[style]}>"
  end

  def timestamp(unix, style) when is_integer(unix) do
    valid = @timestamp_styles |> Map.keys() |> Enum.join(", ")
    raise ArgumentError, "unknown timestamp style #{inspect(style)}, expected: #{valid}"
  end
end
