defmodule EDA.Gateway.Capabilities do
  @moduledoc """
  Gateway capabilities — opt-in protocol behaviour sent in the IDENTIFY payload.

  Capabilities let a bot enable a gateway behaviour before Discord makes it mandatory, so the
  change can be observed and handled ahead of its deadline.

  ## Configuration

      config :eda, capabilities: 32768                  # raw bitfield
      config :eda, capabilities: [:channel_obfuscation] # by name

  Unset (the default) sends no `capabilities` field at all.

  **Discord currently defines no capability.** The only one it ever had,
  `:channel_obfuscation` (`1 <<< 15`), opted a bot into channel obfuscation before
  2026-11-16; since that date obfuscation applies to every bot and the flag changes nothing.
  It is still accepted here, so a configuration written for the opt-in period keeps working,
  and a raw integer passes through for a capability Discord may add later.

  ## Channel obfuscation

  A channel the bot cannot view is still dispatched over the gateway, redacted:

    * `name` becomes `"___hidden___"`,
    * sensitive fields are nulled or reduced,
    * `permission_overwrites` holds a single overwrite denying `VIEW_CHANNEL` to the
      guild's `@everyone` role,
    * the channel's `flags` carry `CHANNEL_OBFUSCATED` (`1 <<< 17`).

  When the bot gains access, a `CHANNEL_UPDATE` brings the full channel. Interaction payloads
  are never obfuscated. Over REST, `GET /guilds/{guild.id}/channels` leaves those channels out
  altogether: on a guild where the gateway dispatched 95 channels, 44 of them obfuscated, the
  endpoint returned the other 51.

  > #### Cache and permissions {: .warning}
  >
  > Obfuscated channels are cached like any other, so `EDA.Cache.channels_for_guild/1`
  > returns `"___hidden___"` entries — reject them with `EDA.Channel.obfuscated?/1` before
  > showing a channel list. `EDA.Permission.in_channel/3` already refuses to compute from
  > the synthetic overwrite and returns `{:error, :channel_obfuscated}`.
  """

  import Bitwise

  @capability_values %{
    channel_obfuscation: 1 <<< 15
  }

  @doc "Returns all capability names EDA knows about."
  @spec all_capabilities() :: [atom()]
  def all_capabilities, do: Map.keys(@capability_values)

  @doc """
  Converts capabilities to a bitfield integer.

  Accepts a list of atoms, a single atom, or a raw integer. A raw integer passes
  through unchanged so that capabilities Discord adds later can be sent without a
  library update.

  ## Examples

      iex> EDA.Gateway.Capabilities.to_bitfield([])
      0

      iex> EDA.Gateway.Capabilities.to_bitfield([:channel_obfuscation])
      32768

      iex> EDA.Gateway.Capabilities.to_bitfield(:channel_obfuscation)
      32768

      iex> EDA.Gateway.Capabilities.to_bitfield(41)
      41
  """
  @spec to_bitfield(non_neg_integer() | atom() | [atom()]) :: non_neg_integer()
  def to_bitfield(bitfield) when is_integer(bitfield) and bitfield >= 0, do: bitfield

  def to_bitfield(capability) when is_atom(capability) and not is_nil(capability),
    do: to_bitfield([capability])

  def to_bitfield(nil), do: 0

  def to_bitfield(capabilities) when is_list(capabilities) do
    Enum.reduce(capabilities, 0, fn capability, acc ->
      case Map.get(@capability_values, capability) do
        nil -> raise ArgumentError, "Unknown gateway capability: #{inspect(capability)}"
        value -> acc ||| value
      end
    end)
  end

  @doc """
  Checks whether a capability is enabled in a bitfield.

  ## Examples

      iex> EDA.Gateway.Capabilities.has_capability?(32768, :channel_obfuscation)
      true

      iex> EDA.Gateway.Capabilities.has_capability?(0, :channel_obfuscation)
      false
  """
  @spec has_capability?(non_neg_integer(), atom()) :: boolean()
  def has_capability?(bitfield, capability) do
    case Map.get(@capability_values, capability) do
      nil -> false
      value -> (bitfield &&& value) == value
    end
  end
end
