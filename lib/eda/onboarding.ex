defmodule EDA.Onboarding do
  @moduledoc """
  A guild's onboarding: the questions new members answer, and the channels they join by default.

      {:ok, onboarding} = EDA.Onboarding.fetch(guild_id)

      onboarding
      |> EDA.Onboarding.add_prompt(
        EDA.Onboarding.prompt("What brings you here?", [
          EDA.Onboarding.option("Gaming", emoji: "🎮", role_ids: [gamer_role]),
          EDA.Onboarding.option("Art", emoji: "🎨", channel_ids: [art_channel])
        ])
      )
      |> EDA.Onboarding.save(reason: "New question")

  ## Saving replaces everything

  Discord's endpoint is a `PUT`: the prompts sent become the whole list, and a prompt left out is
  deleted. So change onboarding by fetching it, editing the struct, and saving it back —
  `save/2` sends every prompt it holds.

  That round trip hides a trap this module takes care of. Discord **returns** an option's emoji as
  an `emoji` object but only **accepts** it as `emoji_id`, `emoji_name` and `emoji_animated`;
  sending back what was read clears every emoji. `to_payload/1` converts them.

  New prompts and options need an `id` in the request although Discord assigns its own on save.
  `prompt/3` and `option/2` fill in a placeholder; the saved onboarding carries Discord's ids.

  ## Enabling

  Saving with `enabled: true` needs the guild to meet Discord's constraints: at least 7 default
  channels, 5 of which `@everyone` can send messages in. `mode: :advanced` counts the questions'
  channels towards them as well. Onboarding requires `MANAGE_GUILD` and `MANAGE_ROLES`.
  """

  use EDA.Event.Access

  alias EDA.Onboarding.{Option, Prompt}

  defstruct [:guild_id, prompts: [], default_channel_ids: [], enabled: false, mode: :default]

  @type mode :: :default | :advanced

  @type t :: %__MODULE__{
          guild_id: String.t() | nil,
          prompts: [Prompt.t()],
          default_channel_ids: [String.t()],
          enabled: boolean(),
          mode: mode() | integer()
        }

  @modes %{0 => :default, 1 => :advanced}

  @doc "Converts a raw onboarding object into this struct."
  @spec from_raw(map()) :: t()
  def from_raw(%__MODULE__{} = parsed), do: parsed

  def from_raw(raw) when is_map(raw) do
    %__MODULE__{
      guild_id: :maps.get("guild_id", raw, nil),
      prompts: Enum.map(:maps.get("prompts", raw, nil) || [], &Prompt.from_raw/1),
      default_channel_ids: :maps.get("default_channel_ids", raw, nil) || [],
      enabled: :maps.get("enabled", raw, nil) || false,
      mode: Map.get(@modes, :maps.get("mode", raw, nil), :maps.get("mode", raw, nil) || :default)
    }
  end

  @doc """
  The request body `save/2` sends: every prompt, with option emojis in the flat form Discord
  accepts, and the mode as its integer.

      iex> onboarding = %EDA.Onboarding{
      ...>   prompts: [EDA.Onboarding.prompt("Q", [%EDA.Onboarding.Option{id: "5", title: "A", emoji: %EDA.Emoji{id: "9", name: "party", animated: true}}], id: "4")],
      ...>   default_channel_ids: ["1"]
      ...> }
      iex> body = EDA.Onboarding.to_payload(onboarding)
      iex> hd(hd(body.prompts).options) |> Map.take([:emoji_id, :emoji_name, :emoji_animated])
      %{emoji_id: "9", emoji_name: "party", emoji_animated: true}
  """
  @spec to_payload(t()) :: map()
  def to_payload(%__MODULE__{} = onboarding) do
    %{
      prompts: Enum.map(onboarding.prompts, &Prompt.to_payload/1),
      default_channel_ids: onboarding.default_channel_ids,
      enabled: onboarding.enabled,
      mode: mode_value!(onboarding.mode)
    }
  end

  @doc false
  def mode_value!(nil), do: nil
  def mode_value!(:default), do: 0
  def mode_value!(:advanced), do: 1
  def mode_value!(n) when n in [0, 1], do: n

  def mode_value!(other),
    do: raise(ArgumentError, "onboarding mode is :default or :advanced, got #{inspect(other)}")

  # ── Builders ───────────────────────────────────────────────────────

  @doc """
  Builds a new prompt.

  ## Options

    * `:type` — `:multiple_choice` (default) or `:dropdown`
    * `:single_select` — members may pick only one option (default `false`)
    * `:required` — members must answer before finishing onboarding (default `false`)
    * `:in_onboarding` — shown during onboarding; `false` shows it only under Channels & Roles
      (default `true`)
    * `:id` — the prompt's id, to replace an existing prompt; a placeholder otherwise
  """
  @spec prompt(String.t(), [Option.t()], keyword()) :: Prompt.t()
  def prompt(title, options, opts \\ []) when is_binary(title) and is_list(options) do
    %Prompt{
      id: opts[:id] || placeholder_id(),
      title: title,
      options: options,
      type: Keyword.get(opts, :type, :multiple_choice),
      single_select: Keyword.get(opts, :single_select, false),
      required: Keyword.get(opts, :required, false),
      in_onboarding: Keyword.get(opts, :in_onboarding, true)
    }
  end

  @doc """
  Builds a new option for a prompt.

  ## Options

    * `:description`
    * `:emoji` — a unicode emoji as a string, or an `EDA.Emoji` struct for a custom one
    * `:channel_ids` — channels a member joins by picking this option
    * `:role_ids` — roles a member gets by picking it
    * `:id` — the option's id, to replace an existing option; a placeholder otherwise

  An option should grant at least one channel or role; Discord refuses one that does neither.
  """
  @spec option(String.t(), keyword()) :: Option.t()
  def option(title, opts \\ []) when is_binary(title) do
    %Option{
      id: opts[:id] || placeholder_id(),
      title: title,
      description: opts[:description],
      emoji: emoji(opts[:emoji]),
      channel_ids: opts |> Keyword.get(:channel_ids, []) |> Enum.map(&to_string/1),
      role_ids: opts |> Keyword.get(:role_ids, []) |> Enum.map(&to_string/1)
    }
  end

  @doc "Appends a prompt."
  @spec add_prompt(t(), Prompt.t()) :: t()
  def add_prompt(%__MODULE__{} = onboarding, %Prompt{} = prompt),
    do: %{onboarding | prompts: onboarding.prompts ++ [prompt]}

  @doc "Removes the prompt with this id."
  @spec remove_prompt(t(), String.t()) :: t()
  def remove_prompt(%__MODULE__{} = onboarding, prompt_id),
    do: %{onboarding | prompts: Enum.reject(onboarding.prompts, &(&1.id == prompt_id))}

  # ── Entity Manager ─────────────────────────────────────────────────

  @doc "Fetches a guild's onboarding."
  @spec fetch(String.t() | integer()) :: {:ok, t()} | {:error, term()}
  def fetch(guild_id) do
    case EDA.API.Guild.onboarding(guild_id) do
      {:ok, raw} -> {:ok, from_raw(raw)}
      error -> error
    end
  end

  @doc """
  Saves the whole onboarding — every prompt it holds — and returns it as Discord stored it.

  ## Options

    * `:reason` — audit log reason
  """
  @spec save(t(), keyword()) :: {:ok, t()} | {:error, term()}
  def save(%__MODULE__{guild_id: guild_id} = onboarding, opts \\ []) when not is_nil(guild_id) do
    body = to_payload(onboarding)

    case EDA.API.Guild.modify_onboarding(guild_id, Map.merge(body, Map.new(opts))) do
      {:ok, raw} -> {:ok, from_raw(raw)}
      error -> error
    end
  end

  # Discord requires an id on a new prompt or option but replaces it with its own; any snowflake
  # does. The low bits keep ids made in the same millisecond apart.
  defp placeholder_id do
    ms = System.os_time(:millisecond) - EDA.Snowflake.discord_epoch()
    Integer.to_string(Bitwise.bsl(ms, 22) + rem(System.unique_integer([:positive]), 4_194_304))
  end

  defp emoji(nil), do: nil
  defp emoji(%EDA.Emoji{} = emoji), do: emoji
  defp emoji(unicode) when is_binary(unicode), do: %EDA.Emoji{name: unicode}
end
